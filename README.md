# CloudDevOpsProject

Microservices DevOps training project (NTI x iVolve). The application source
code lives in [`src/`](./src).

| Service         | Technology               | Port |
| --------------- | ------------------------ | ---- |
| Frontend        | Node.js / Express / EJS  | 3000 |
| Auth Service    | Python / Flask           | 5000 |
| Roadmap Service | Java / Spring Boot       | 8080 |
| MySQL           | MySQL 8                  | 3306 |

## Running the stack locally (Docker Compose)

The repository ships a [`docker-compose.yml`](./docker-compose.yml) that builds
every microservice from its own Dockerfile and starts the application together
with a local MySQL database.

```bash
# Build the images and start everything in the background
docker compose up --build -d

# Check that all four containers are healthy
docker compose ps

# Follow the logs
docker compose logs -f frontend

# Stop the stack (add -v to also delete the database volume)
docker compose down -v
```

Then open <http://localhost:3000> and create an account to reach the DevOps
roadmap page.

### Verifying the stack

```bash
# Database + auth service health
curl http://localhost:5000/health
# {"database":"connected","status":"UP"}

# Roadmap service
curl http://localhost:8080/api/roadmap

# Sign up / log in through the auth service
curl -X POST http://localhost:5000/api/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{"username":"john@example.com","password":"password123"}'

curl -X POST http://localhost:5000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"john@example.com","password":"password123"}'
```

### Configuration

All ports, database credentials and secrets can be overridden with environment
variables or with a local `.env` file. Copy the template and edit it:

```bash
cp .env.example .env
```

`.env` must never be committed to git.

### Default local credentials

| Variable            | Default        |
| ------------------- | -------------- |
| `MYSQL_DATABASE`    | `ivolve`       |
| `MYSQL_USER`        | `ibrahim`      |
| `MYSQL_PASSWORD`    | `pass@123`     |
| `MYSQL_ROOT_PASSWORD` | `rootpassword` |
| `SESSION_SECRET`    | `change-me-in-k8s` |
