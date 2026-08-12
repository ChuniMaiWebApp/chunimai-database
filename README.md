# ChunithmWebApp — Database & Infrastructure

Database schemas, Docker containers, and infrastructure configurations for ChunithmWebApp.

## Quickstart (Localhost)

### 1. Prerequisites
- Docker & Docker Compose

### 2. Run Local Postgres & Redis

```bash
# Clone repository
git clone https://github.com/ChuniMaiWebApp/chunimai-database.git
cd chunimai-database

# Start local Postgres & Redis containers
docker compose -f dev-stack/docker-compose.yml up -d
```

Connection endpoints:
- PostgreSQL: `localhost:5432` (`postgres` / `postgres`)
- Redis: `localhost:6379`

### Docker Commands

```bash
# Check running containers
docker compose -f dev-stack/docker-compose.yml ps

# View container logs
docker compose -f dev-stack/docker-compose.yml logs -f

# Stop local services
docker compose -f dev-stack/docker-compose.yml down
```

---

## Credits & Acknowledgements

Special thanks to the open-source community and project creators whose work made this platform possible:

- **[chuni-penguin](https://github.com/beer-psi/chuni-penguin)** by [beerpsi](https://github.com/beer-psi) — The original inspiration for this project.
- **[chunirec](https://developer.chunirec.net/)** — Essential chart constants and rating dataset.
- **[arcade-songs](https://github.com/zetaraku/arcade-songs)** by [zetaraku](https://github.com/zetaraku) — Data mapping and schema references.
