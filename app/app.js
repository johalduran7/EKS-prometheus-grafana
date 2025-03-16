const express = require('express');
const { Client } = require('pg');
const promClient = require('prom-client');

const app = express();
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// HTTP request counter
const httpRequestCounter = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// Database interaction counters
const dbOperationCounter = new promClient.Counter({
  name: 'db_operations_total',
  help: 'Total number of database operations',
  labelNames: ['operation'],
  registers: [register],
});

const client = new Client({
  host: process.env.PGHOST || 'localhost',
  user: process.env.PGUSER || 'postgres',
  password: process.env.PGPASSWORD || 'password',
  database: process.env.PGDATABASE || 'people',
  port: process.env.PGPORT || 5432,
});

client.connect().then(async () => {
  await client.query(`
    CREATE TABLE IF NOT EXISTS people (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100),
      phone VARCHAR(20),
      email VARCHAR(100)
    )
  `);
}).catch(err => {
  console.error('Failed to connect:', err);
  process.exit(1);
});

app.use((req, res, next) => {
  httpRequestCounter.inc({ 
    method: req.method, 
    route: req.route ? req.route.path : req.path,
    status: res.statusCode.toString() // capture status too
  });
  next();
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/', async (req, res) => {
  dbOperationCounter.inc({ operation: 'select' });

  const result = await client.query('SELECT * FROM people ORDER BY id DESC');
  const people = result.rows;

  res.send(`
    <html>
    <head>
      <title>K8s-App Demo</title>
      <style>
        body {
          background-color: #0d1117;
          color: white;
          font-family: Arial, sans-serif;
          padding: 20px;
        }
        form, table {
          background-color: #161b22;
          padding: 15px;
          border-radius: 8px;
          box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
          margin-bottom: 15px;
        }
        input, button {
          margin: 5px;
          padding: 10px;
          border: none;
          border-radius: 8px;
        }
        button {
          background-color: #f0b400;
          cursor: pointer;
          color: #0d1117;
          font-weight: bold;
        }
        table {
          width: 100%;
          border-collapse: collapse;
        }
        th, td {
          padding: 10px;
          border: 1px solid #30363d;
        }
        th {
          background-color: #21262d;
        }
        td input {
          background-color: #0d1117;
          color: white;
          border: none;
          width: 100%;
        }
      </style>
      <script>
        async function updatePerson(id, field, value) {
          await fetch('/update', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id, field, value })
          });
        }

        async function deletePerson(id) {
          if (confirm('Are you sure you want to delete this record?')) {
            await fetch('/delete/' + id, { method: 'DELETE' });
            window.location.reload();
          }
        }

        function handleEdit(event, id, field) {
          const value = event.target.value;
          updatePerson(id, field, value);
        }
      </script>
    </head>
    <body>
      <h1>🚀 John Durán's K8s-App and ArgoCD Demo</h1>

      <form action="/submit" method="POST">
        <input type="text" name="name" placeholder="Name" required />
        <input type="text" name="phone" placeholder="Phone" required />
        <input type="email" name="email" placeholder="Email" required />
        <button type="submit">Submit</button>
      </form>

      <h2>📋 Stored People:</h2>
      <table>
        <thead>
          <tr>
            <th>ID</th><th>Name</th><th>Phone</th><th>Email</th><th>Actions</th>
          </tr>
        </thead>
        <tbody>
          ${people.map(p => `
            <tr>
              <td>${p.id}</td>
              <td><input value="${p.name}" onblur="handleEdit(event, ${p.id}, 'name')" /></td>
              <td><input value="${p.phone}" onblur="handleEdit(event, ${p.id}, 'phone')" /></td>
              <td><input value="${p.email}" onblur="handleEdit(event, ${p.id}, 'email')" /></td>
              <td><button onclick="deletePerson(${p.id})">Delete</button></td>
            </tr>
          `).join('')}
        </tbody>
      </table>
      <h2>🖼️ ArgoCD Deployment</h2>
      <img src="https://raw.githubusercontent.com/johalduran7/EKS-prometheus-grafana/master/resources/Argo_CD.png" alt="ArgoCD Deployment" style="max-width: 100%; border-radius: 8px; box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);" />
    </body>
    </html>
  `);
});

app.post('/submit', async (req, res) => {
  const { name, phone, email } = req.body;
  dbOperationCounter.inc({ operation: 'insert' });

  await client.query('INSERT INTO people (name, phone, email) VALUES ($1, $2, $3)', [name, phone, email]);
  res.redirect('/');
});

app.post('/update', async (req, res) => {
  const { id, field, value } = req.body;
  const validFields = ['name', 'phone', 'email'];
  if (!validFields.includes(field)) return res.status(400).send('Invalid field');

  dbOperationCounter.inc({ operation: 'update' });

  await client.query(`UPDATE people SET ${field} = $1 WHERE id = $2`, [value, id]);
  res.sendStatus(200);
});

app.delete('/delete/:id', async (req, res) => {
  const { id } = req.params;
  dbOperationCounter.inc({ operation: 'delete' });

  await client.query('DELETE FROM people WHERE id = $1', [id]);
  res.sendStatus(200);
});

const PORT = 3000;
app.listen(PORT, () => console.log(`🚀 App running on port ${PORT}`));
