#!/usr/bin/env bash
set -euo pipefail

# Colors and styling (consistent with install_and_run)
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[96m"
GREEN="\033[92m"
RED="\033[91m"
YELLOW="\033[93m"

# Icons
ICON_ARROW="→"
ICON_CHECK="✓"
ICON_CROSS="✗"

# Logging functions
log_step() {
	echo -e "${BOLD}${CYAN}${ICON_ARROW} $1${RESET}"
}

log_success() {
	echo -e "${BOLD}${GREEN}${ICON_CHECK} $1${RESET}"
}

log_error() {
	echo -e "${BOLD}${RED}${ICON_CROSS} $1${RESET}" >&2
}

log_warning() {
	echo -e "${BOLD}${YELLOW}⚠ $1${RESET}"
}

log_detail() {
	echo -e "  ${DIM}$1${RESET}"
}

# Configuration variables
LOCAL_BIN="${HOME}/.local/bin"
FOUNDRY_BIN="${HOME}/.foundry/bin"
RISC0_BIN="${HOME}/.risc0/bin"
FOUNDRY_INSTALL_URL="https://foundry.paradigm.xyz"
RISC0_INSTALL_URL="https://risczero.com/install"
ENCLAVE_INSTALL_URL="https://raw.githubusercontent.com/gnosisguild/enclave/main/install"
ENCLAVE_REPO_URL="https://github.com/gnosisguild/enclave.git"
CRISP_DIR="/workspace/project/examples/CRISP"
RETRY_COUNT=3
RETRY_DELAY=5

# Utility functions
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

retry() {
	local attempts=$1
	shift
	local count=0
	until "$@"; do
		exit_code=$?
		count=$((count + 1))
		if [ $count -lt "$attempts" ]; then
			log_warning "Command failed (attempt $count/$attempts). Retrying in ${RETRY_DELAY}s..."
			sleep $RETRY_DELAY
		else
			log_error "Command failed after $attempts attempts"
			return $exit_code
		fi
	done
}

setup_path() {
	# Add LOCAL_BIN to PATH if not already present
	if ! grep -q "$LOCAL_BIN" ~/.bashrc 2>/dev/null; then
		log_detail "Adding $LOCAL_BIN to PATH in ~/.bashrc"
		echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >>~/.bashrc
	fi

	# Export PATH for current session
	export PATH="$LOCAL_BIN:$PATH"

	# Add FOUNDRY_BIN to PATH if exists
	if [ -d "$FOUNDRY_BIN" ]; then
		export PATH="$FOUNDRY_BIN:$PATH"
	fi

	# Add RISC0_BIN to PATH if exists
	if [ -d "$RISC0_BIN" ]; then
		export PATH="$RISC0_BIN:$PATH"
	fi

	SHELL=/bin/bash pnpm setup
	export PNPM_HOME="/root/.local/share/pnpm"
	case ":$PATH:" in
	  *":$PNPM_HOME:"*) ;;
	  *) export PATH="$PNPM_HOME:$PATH" ;;
	esac
	pnpm self-update
}

install_foundry() {
	if command_exists foundryup; then
		log_success "Foundry already installed"
		return 0
	fi

	log_step "Installing Foundry..."
	if retry $RETRY_COUNT curl -L "$FOUNDRY_INSTALL_URL" | bash; then
		# Re-export PATH after installation
		if [ -d "$FOUNDRY_BIN" ]; then
			export PATH="$FOUNDRY_BIN:$PATH"
		fi

		if command_exists foundryup; then
			foundryup
			log_success "Foundry installed successfully"
		else
			log_error "Foundry installation failed"
			exit 1
		fi
	else
		log_error "Failed to download Foundry installer"
		exit 1
	fi
}

install_rzup() {
	if command_exists rzup; then
		log_success "rzup already installed"
		return 0
	fi

	log_step "Installing rzup..."
	if retry $RETRY_COUNT curl -fsSL "$RISC0_INSTALL_URL" | bash; then
		# Re-export PATH after installation
		if [ -d "$RISC0_BIN" ]; then
			export PATH="$RISC0_BIN:$PATH"
		fi

		if command_exists rzup; then
			log_success "rzup installed successfully"
		else
			log_error "rzup installation failed"
			exit 1
		fi
	else
		log_error "Failed to download rzup installer"
		exit 1
	fi
}

install_risczero_toolchain() {
	if command_exists cargo-risczero; then
		log_success "RISC Zero toolchain already installed"
		return 0
	fi

	log_step "Installing RISC Zero toolchain..."
	if retry $RETRY_COUNT rzup install cargo-risczero; then
		log_success "RISC Zero toolchain installed successfully"
	else
		log_error "Failed to install RISC Zero toolchain"
		exit 1
	fi
}

install_enclave() {
	if command_exists enclave; then
		log_success "Enclave CLI already installed"
		return 0
	fi

	# Install enclaveup if not present
	if ! command_exists enclaveup; then
		log_step "Installing enclaveup..."
		if retry $RETRY_COUNT curl -fsSL "$ENCLAVE_INSTALL_URL" | bash; then
			export PATH="$LOCAL_BIN:$PATH"

			# Try alternative paths if needed
			if ! command_exists enclaveup; then
				log_detail "Searching for enclaveup in alternative paths..."
				for path in "$HOME/.local/bin" "/root/.local/bin" "$HOME/.cargo/bin"; do
					if [ -f "$path/enclaveup" ]; then
						log_detail "Found enclaveup at $path"
						export PATH="$path:$PATH"
						break
					fi
				done
			fi

			if command_exists enclaveup; then
				log_success "enclaveup installed successfully"
			else
				log_error "enclaveup installation failed"
				exit 1
			fi
		else
			log_error "Failed to download enclaveup installer"
			exit 1
		fi
	fi

	# Install Enclave CLI
	log_step "Installing Enclave CLI..."
	if retry $RETRY_COUNT enclaveup install; then
		export PATH="$LOCAL_BIN:$PATH"
		if command_exists enclave; then
			log_success "Enclave CLI installed successfully"
		else
			log_error "Enclave CLI installation failed"
			exit 1
		fi
	else
		log_error "Failed to install Enclave CLI"
		exit 1
	fi
}

initialize_project() {
	if [ -f "project/package.json" ]; then
		log_success "Enclave CRISP template project already initialized"
		return 0
	fi

	log_step "Initializing Enclave CRISP template project..."
	if retry $RETRY_COUNT git clone $ENCLAVE_REPO_URL --recurse-submodules tmp -q; then
		log_step "Copying files to project directory..."
		rsync -a --ignore-existing tmp/ project/
		rm -rf tmp
		chmod -R 777 project
		log_success "Enclave CRISP template project initialized"
	else
		log_error "Failed to initialize Enclave CRISP template project"
		exit 1
	fi
}

prepare_project() {
	log_step "Ensuring pnpm dependencies are installed..."
	cd project
	CI=true pnpm install --frozen-lockfile -s
	cd $CRISP_DIR
	pnpm dev:setup
	CI=true pnpm install --frozen-lockfile -s
	cd ../..
	log_step "Ensuring permissions are set correctly..."
	chmod -R 777 .
	cd ..
	log_step "Applying additional fixes..." # Remove yq & fix wrong ciphernode addresses
	sed -i 's|CN\([1-3]\)=\$(cat ./enclave.config.yaml \| yq '"'"'.nodes.cn\1.address'"'"')|CN\1=$(grep -A 1 '"'"'cn\1:'"'"' enclave.config.yaml \| grep '"'"'address:'"'"' \| sed '"'"'s/.*address: *"\\([^"]*\\)".*/\\1/'"'"')|g' project/examples/CRISP/scripts/dev_cipher.sh
}

start_project() {
	log_step "Starting development environment..."
	cd $CRISP_DIR
	pnpm dev:up
}

# Main execution
main() {
	log_step "Setting up Enclave CRISP template development environment..."

	# Setup PATH
	setup_path

	# Install dependencies
	install_foundry
	install_rzup
	install_risczero_toolchain
	install_enclave

	# Initialize and start project
	initialize_project
	prepare_project
	start_project
}

# Run main function
main "$@"
