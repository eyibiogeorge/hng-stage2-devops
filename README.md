# DevOps Intern Stage 2 Task -  Blue/Green with Nginx Upstreams (Auto-Failover + Manual Toggle)

This project implements a blue-green deployment strategy using Docker Compose, Nginx as a reverse proxy, and two application instances (`blue` and `green`) running the [yimikaade/wonderful:devops-stage-two](https://hub.docker.com/r/yimikaade/wonderful/tags) image. The setup supports zero-downtime deployments with automatic failover and header validation for release tracking.

## Features

- **Blue-Green Deployment:** Two application instances (`app_blue` and `app_green`) allow switching between deployments without downtime.

- **Nginx Reverse Proxy:** Routes traffic to the active pool (`blue` or `green`) with failover to the backup pool on errors (HTTP 5xx, timeouts, or connection issues).

- **Dynamic Configuration:** Uses `envsubst` to generate Nginx configurations based on environment variables.

- **Header Validation:** Verifies `X-App-Pool` and `X-Release-Id` headers in responses to ensure correct routing and release tracking.

- **Automated Deployment:** A Bash script (`deploy-stage2.sh`) handles setup, validation, and error logging.

## Prerequisites

- **Docker:** Ensure Docker is installed and running.

- **Docker Compose V2:** Required for managing the multi-container setup (`docker compose` preferred over `docker-compose`).

- **Bash:** A Bash-compatible shell for running the deployment script.

- **Port Availability:** Ports `8080`, `8081`, and `8082` must be free on the host.

## Directory Structure

```bash
hng-stage2-devops/
├── docker-compose.yml           # Defines Nginx, app_blue, and app_green services
├── config/
│   └── nginx.conf.template      # Nginx configuration template for envsubst
├── .env                        # Environment variables for configuration
├── .env.example                # Example environment variables
└── deploy-stage2.sh            # Deployment script
```

## Setup Instructions

1. **Clone the Repository**
    ```bash
    git clone <https://github.com/eyibiogeorge/hng-stage2-devops.git>
    cd hng-stage2-devops
    ```
2. **Create Directory Structure:**
```bash
mkdir -p config
```

3. **Configure Environment Variables:**

    - Copy the example `.env` file:
        ```bash
        cp .env.example .env
        ```
    - Edit .`env` to set the required variables:

        ```bash
        BLUE_IMAGE=yimikaade/wonderful:devops-stage-two
        GREEN_IMAGE=yimikaade/wonderful:devops-stage-two
        ACTIVE_POOL=blue
        RELEASE_ID_BLUE=blue-release-1.0.0
        RELEASE_ID_GREEN=green-release-1.0.0
        PORT=8080
        PORT_BLUE=8081
        PORT_GREEN=8082
        ```
    - Ensure `BLUE_IMAGE` and `GREEN_IMAGE` point to valid Docker images, and `ACTIVE_POOL` is either `blue` or `green`.

4. **Verify Files:**

    - Confirm the presence of `docker-compose.yml`, `config/nginx.conf.template`, `.env`, and `deploy-stage2.sh`:

        ```bash
        ls -l
        ls -l config/
        ```
    
5. Make the Deployment Script Executable:
    ```bash
    chmod +x deploy-stage2.sh
    ```

## Deployment

Run the deployment script to start the services:
```bash
./deploy-stage2.sh
```
The script:

- Checks for required files and environment variables.

- Verifies port availability (`8080`, `8081`, `8082`).

- Pulls Docker images.

- Starts Docker Compose services (`nginx`, `app_blue`, `app_green`).

- Validates the deployment by checking the /version endpoint and response headers.

- Logs output to `deploy_stage2_YYYYMMDD_HHMMSS.log.`

## Testing

1. **Baseline Test:**

    ```bash
    curl -v http://localhost:8080/version
    ```
    **Expected Output:**

    - HTTP 200

    - Headers: `X-App-Pool`: `blue`, `X-Release-Id`: `blue-release-1.0.0` (if `ACTIVE_POOL=blue`)

2. **Failover Test:**

    - Induce chaos on the blue pool:

        ```bash
        curl -X POST http://localhost:8081/chaos/start?mode=error
        ```

    - Verify switch to green:
        ```bash
        curl -v http://localhost:8080/version
        ```
    **Expected Output:**

    - HTTP 200

    - Headers: X-App-Pool: green, X-Release-Id: green-release-1.0.0

    - Test stability:

        ```bash
        for i in {1..20}; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/version; done
        ```

    **Expected Output:** All 200 responses, ~100% green responses.

    - Stop chaos:

        ```bash
        curl -X POST http://localhost:8081/chaos/stop
        ```

3. Manual Pool Switch:

    - Edit `.env` to set `ACTIVE_POOL=green`:
        ```bash
        nano .env
        ```

    - Restart Nginx:
        ```bash
        docker compose down
        docker compose up -d nginx
        ```

    - Verify:
        ```bash
        curl -v http://localhost:8080/version
        ```

## Troubleshooting

- **Port Conflict:**
    ```bash
    ss -tulnp | grep ":8080"
    sudo fuser -k 8080/tcp
    ```
- **Container Logs:**

    ```bash
    docker compose logs nginx
    docker compose logs app_blue
    docker compose logs app_green
    ```

- Nginx Configuration:

    ```bash
    docker compose exec nginx cat /tmp/nginx_config.log
    docker compose exec nginx cat /tmp/nginx_config_error.log
    ```

- Direct Application Test:

    ```bash
    curl -v http://localhost:8081/version  # app_blue
    curl -v http://localhost:8082/version  # app_green
    ```

- Check Container Status:
    ```bash
    docker compose ps
    ```
## Configuration Details

- **docker-compose.yml:**

    - Defines three services: `nginx`, `app_blue`, and `app_green`.

    - Maps host ports `8080` (Nginx), `8081` (blue), and `8082` (green) to container ports.

    - Uses `nginx:1.25-alpine` with runtime `gettext` installation for `envsubst`.

- **nginx.conf.template:**

 - Configures upstream blocks (`blue_pool`, `green_pool`) and routes traffic to the active pool (`${ACTIVE_POOL}_pool`).

    - Supports failover with `proxy_next_upstream` for errors and timeouts.

- deploy-stage2.sh:

    - Validates files, environment variables, and ports.

    - Logs errors and container output for debugging.

    - Verifies headers (`X-App-Pool`, `X-Release-Id`) in responses.

