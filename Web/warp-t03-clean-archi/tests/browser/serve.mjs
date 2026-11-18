import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

const assets = new Map([
  ['/', ['index.html', 'text/html']],
  ['/styles.css', ['styles.css', 'text/css']],
  ['/elm.js', ['elm.js', 'application/javascript']]
]);

createServer(async (request, response) => {
  const asset = assets.get(new URL(request.url, 'http://localhost').pathname);
  if (!asset) {
    response.writeHead(404).end();
    return;
  }
  try {
    const body = await readFile(new URL(`../../www/${asset[0]}`, import.meta.url));
    response.writeHead(200, { 'Content-Type': asset[1] }).end(body);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    response.writeHead(500).end('Build the frontend with npm run build first.');
  }
}).listen(4173, '127.0.0.1');
