const fetch = require('node-fetch');

async function testSearchAPI() {
    try {
        // Test without authentication first
        console.log("Testing without authentication...");
        const response1 = await fetch('http://localhost:14702/users/search?query=pa&limit=10');
        console.log("Status:", response1.status);
        console.log("Response:", await response1.text());
        
        console.log("\n" + "=".repeat(50) + "\n");
        
        // You would need to replace this with a real session token
        // For now, let's just see the structure
        console.log("Testing with fake session token...");
        const response2 = await fetch('http://localhost:14702/users/search?query=pa&limit=10', {
            headers: {
                'X-Session-Token': 'fake-token-here',
                'Content-Type': 'application/json'
            }
        });
        console.log("Status:", response2.status);
        console.log("Response:", await response2.text());
        
    } catch (error) {
        console.error("Error:", error.message);
    }
}

testSearchAPI();