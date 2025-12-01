use revolt_config::config;
use revolt_database::{Database, FileHash, Metadata, User, iso8601_timestamp::Timestamp};
use revolt_files::{upload_to_s3, fetch_from_s3, AUTHENTICATION_TAG_SIZE_BYTES};
use revolt_result::{create_error, Result};
use rocket::data::{Data, ToByteUnit};
use rocket::http::ContentType;
use rocket::serde::json::Json;
use rocket::State;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use sha2::Digest;
use multer::Multipart;
use futures::stream;

/// Successful upload response
#[derive(Serialize, Deserialize, JsonSchema)]
pub struct UploadResponse {
    /// ID to attach uploaded file to object
    pub id: String,
}

/// Upload a file attachment
///
/// This endpoint accepts multipart/form-data file uploads and stores them in S3 and MongoDB.
/// It replaces the broken Autumn service for attachment uploads.
#[openapi(tag = "Files")]
#[post("/attachments", data = "<data>")]
pub async fn upload_attachment(
    db: &State<Database>,
    user: User,
    content_type: &ContentType,
    data: Data<'_>,
) -> Result<Json<UploadResponse>> {

    // Verify content type is multipart/form-data
    if !content_type.is_form_data() {
        return Err(create_error!(InvalidOperation));
    }

    // Get configuration
    let config = config().await;

    // Get user's file upload limits
    let limits = user.limits().await;
    let size_limit = limits
        .file_upload_size_limit
        .get("attachments")
        .copied()
        .unwrap_or(20 * 1024 * 1024); // Default 20MB

    // Extract boundary from content type
    let boundary = content_type
        .params()
        .find(|(k, _)| k == &"boundary")
        .map(|(_, v)| v.to_string())
        .ok_or_else(|| create_error!(InvalidOperation))?;

    // Read data into buffer first (Rocket's DataStream isn't compatible with multer)
    let stream = data.open(size_limit.bytes());
    let mut buffer = Vec::new();
    if stream.stream_to(&mut buffer).await.is_err() {
        return Err(create_error!(InvalidOperation));
    }

    // Create a stream from the buffer for multer
    let cursor = std::io::Cursor::new(buffer);
    let byte_stream = stream::once(async move { Ok::<_, std::io::Error>(cursor.into_inner()) });
    
    // Create multipart parser
    let mut multipart = Multipart::new(byte_stream, boundary);
    
    // Process fields
    while let Some(field) = multipart.next_field().await.map_err(|_| create_error!(InvalidOperation))? {
        if field.name() == Some("file") {
            let filename = field
                .file_name()
                .unwrap_or("unnamed-file")
                .to_string();
            
            // Read binary data directly - NO UTF-8 CONVERSION
            let content = field.bytes().await
                .map_err(|_| create_error!(InvalidOperation))?
                .to_vec();
            
            let original_file_size = content.len();

            // Ensure the file is not empty
            if original_file_size < config.files.limit.min_file_size {
                return Err(create_error!(FileTooSmall));
            }

            // Check size limit
            if original_file_size > size_limit {
                return Err(create_error!(FileTooLarge { max: size_limit }));
            }

            // Generate sha256 hash
            let original_hash = {
                let mut hasher = sha2::Sha256::new();
                hasher.update(&content);
                hasher.finalize()
            };

            // Generate an ID for this file
            let id = nanoid::nanoid!(42);

            // Determine the mime type for the file
            let mime_type = determine_mime_type(&content, &filename);

            // Check blocklist for mime type
            if config
                .files
                .blocked_mime_types
                .iter()
                .any(|m| m == &mime_type)
            {
                return Err(create_error!(FileTypeNotAllowed));
            }

            // For attachments, we accept any file type
            let metadata = Metadata::File;

            // Find an existing hash and use that if possible
            let file_hash_exists = if let Ok(file_hash) = db
                .fetch_attachment_hash(&format!("{original_hash:02x}"))
                .await
            {
                if !file_hash.iv.is_empty() {
                    db.insert_attachment(&file_hash.into_file(
                        id.clone(),
                        "attachments".to_owned(),
                        filename.clone(),
                        user.id.clone(),
                    ))
                    .await?;

                    return Ok(Json(UploadResponse { id }));
                }

                true
            } else {
                false
            };

            // Calculate new file size with encryption overhead
            let new_file_size = content.len() + AUTHENTICATION_TAG_SIZE_BYTES;
            let processed_hash = {
                let mut hasher = sha2::Sha256::new();
                hasher.update(&content);
                hasher.finalize()
            };

            log::info!("Uploading file {} - size: {} bytes, mime: {}",
                filename, original_file_size, mime_type);

            // Create hash entry in database
            let file_hash = FileHash {
                id: format!("{original_hash:02x}"),
                processed_hash: format!("{processed_hash:02x}"),
                created_at: Timestamp::now_utc(),
                bucket_id: config.files.s3.default_bucket,
                path: format!("{original_hash:02x}"),
                iv: String::new(), // indicates file is not uploaded yet
                metadata,
                content_type: mime_type.clone(),
                size: new_file_size as isize,
            };

            // Add attachment hash if it doesn't exist
            if !file_hash_exists {
                db.insert_attachment_hash(&file_hash).await?;
            }

            // Upload the file to S3 and commit nonce to database
            let nonce = upload_to_s3(&file_hash.bucket_id, &file_hash.id, &content).await?;
            db.set_attachment_hash_nonce(&file_hash.id, &nonce).await?;

            log::info!("Successfully uploaded file {} to S3 with ID {}", filename, id);

            // Finally, create the file and return its ID
            db.insert_attachment(&file_hash.into_file(
                id.clone(),
                "attachments".to_owned(),
                filename,
                user.id.clone(),
            ))
            .await?;

            return Ok(Json(UploadResponse { id }));
        }
    }

    Err(create_error!(InvalidOperation))
}

/// Determine MIME type from file content and name - IMPROVED VERSION
fn determine_mime_type(content: &[u8], filename: &str) -> String {
    // First, try extension-based detection (most reliable for Office files)
    if let Some(ext) = filename.split('.').last() {
        let mime = match ext.to_lowercase().as_str() {
            // Text formats
            "txt" => "text/plain",
            "csv" => "text/csv",
            "md" => "text/markdown",
            
            // Documents
            "pdf" => "application/pdf",
            "doc" => "application/msword",
            "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "rtf" => "application/rtf",
            "xls" => "application/vnd.ms-excel",
            "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt" => "application/vnd.ms-powerpoint",
            "pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "epub" => "application/epub+zip",
            "odt" => "application/vnd.oasis.opendocument.text",
            "ods" => "application/vnd.oasis.opendocument.spreadsheet",
            "odp" => "application/vnd.oasis.opendocument.presentation",
            
            // Data formats
            "json" => "application/json",
            "xml" => "application/xml",
            "yaml" | "yml" => "text/yaml",
            
            // Archives
            "zip" => "application/zip",
            "rar" => "application/x-rar-compressed",
            "7z" => "application/x-7z-compressed",
            "tar" => "application/x-tar",
            "gz" => "application/gzip",
            
            // Code/Data
            "py" => "text/x-python",
            "js" => "text/javascript",
            "ts" => "text/typescript",
            "sql" => "application/sql",
            "html" | "htm" => "text/html",
            "css" => "text/css",
            "java" => "text/x-java-source",
            "cpp" | "cc" | "cxx" => "text/x-c++src",
            "cs" => "text/x-csharp",
            "sh" => "application/x-sh",
            "rb" => "text/x-ruby",
            "php" => "text/x-php",
            
            // Images - will fallback to content detection
            "png" | "jpg" | "jpeg" | "gif" | "webp" | "svg" | "tif" | "tiff" | "bmp" | "ico" => "",
            
            // Other
            "ics" => "text/calendar",
            "ttf" => "font/ttf",
            "plist" => "application/x-plist",
            
            _ => "",
        };
        
        // If we found a MIME type from extension, use it
        if !mime.is_empty() {
            return mime.to_string();
        }
    }
    
    // Fallback to content-based detection (good for images)
    if let Some(kind) = infer::get(content) {
        return kind.mime_type().to_string();
    }

    // Default fallback
    "application/octet-stream".to_string()
}

/// Download a file attachment
#[openapi(tag = "Files")]
#[get("/attachments/<id>")]
pub async fn download_attachment(
    db: &State<Database>,
    id: String,
) -> Result<(ContentType, Vec<u8>)> {
    // Fetch file metadata from database - needs tag and file_id
    let file = db.fetch_attachment("attachments", &id).await?;
    
    // Get the hash field from the file
    let hash = file.hash.as_ref()
        .ok_or_else(|| create_error!(NotFound))?;
    
    // Fetch the hash entry to get S3 location
    let file_hash = db.fetch_attachment_hash(hash).await?;
    
    // Download from S3 using bucket_id, path (which is the hash), and nonce (iv)
    let data = fetch_from_s3(&file_hash.bucket_id, &file_hash.path, &file_hash.iv).await?;
    
    // Parse content type from the file metadata
    let content_type = ContentType::parse_flexible(&file.content_type)
        .unwrap_or(ContentType::Binary);
    
    Ok((content_type, data))
}

/// Download a file attachment with size variant (original, preview, etc.)
#[openapi(tag = "Files")]
#[get("/attachments/<id>/<_size>")]
pub async fn download_attachment_sized(
    db: &State<Database>,
    id: String,
    _size: String,
) -> Result<(ContentType, Vec<u8>)> {
    // For now, ignore size parameter and return original
    download_attachment(db, id).await
}
