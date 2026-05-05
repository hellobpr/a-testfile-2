const express = require('express');

const app = express();
const PORT = 3000;

// --- Basic Logging Middleware ---
app.use((req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(
      `${req.method} ${req.originalUrl} ${res.statusCode} - ${duration}ms`
    );
  });

  next();
});

// --- Routes ---

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    version: "v1",
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

//ERROR (version v2)
// app.get('/health', (req, res) => {
//   throw new Error('Broken deployment v2');
// });

// Mock users data
const users = [
  { id: 1, name: 'Alice', email: 'alice@example.com' },
  { id: 2, name: 'Bob', email: 'bob@example.com' },
  { id: 3, name: 'Charlie', email: 'charlie@example.com' },
];

// Users endpoint
app.get('/users', (req, res) => {
  res.json(users);
});


// --- Start Server ---
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = app;