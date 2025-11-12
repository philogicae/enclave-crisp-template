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
NOIRUP_BIN="${HOME}/.nargo/bin"
FOUNDRY_INSTALL_URL="https://foundry.paradigm.xyz"
RISC0_INSTALL_URL="https://risczero.com/install"
NOIRUP_INSTALL_URL="https://raw.githubusercontent.com/noir-lang/noirup/refs/heads/main/install"
WASMPACK_INSTALL_URL="https://drager.github.io/wasm-pack/installer/init.sh"
ENCLAVE_INSTALL_URL="https://raw.githubusercontent.com/gnosisguild/enclave/main/install"
ENCLAVE_REPO_URL="https://github.com/gnosisguild/enclave.git"
CRISP_DIR="/workspace/project/examples/CRISP"
RETRY_COUNT=3
RETRY_DELAY=5

# Utility functions
# Check if a command exists in the system PATH
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Retry mechanism for commands that may fail intermittently
# Usage: retry <attempts> <command>
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

# Setup environment PATH for all installed tools
setup_path() {
	# Add LOCAL_BIN to PATH if not already present in ~/.bashrc
	if ! grep -q "$LOCAL_BIN" ~/.bashrc 2>/dev/null; then
		log_detail "Adding $LOCAL_BIN to PATH in ~/.bashrc"
		echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >>~/.bashrc
	fi

	# Export PATH for current session
	export PATH="$LOCAL_BIN:$PATH"

	# Add Foundry binary directory to PATH if exists
	if [ -d "$FOUNDRY_BIN" ]; then
		export PATH="$FOUNDRY_BIN:$PATH"
	fi

	# Add RISC0 binary directory to PATH if exists
	if [ -d "$RISC0_BIN" ]; then
		export PATH="$RISC0_BIN:$PATH"
	fi

	# Add NoirUP binary directory to PATH if exists
	if [ -d "$NOIRUP_BIN" ]; then
		export PATH="$NOIRUP_BIN:$PATH"
	fi

	# Setup pnpm environment and update PATH
	SHELL=/bin/bash pnpm setup
	export PNPM_HOME="/root/.local/share/pnpm"
	case ":$PATH:" in
	  *":$PNPM_HOME:"*) ;;
	  *) export PATH="$PNPM_HOME:$PATH" ;;
	esac
	pnpm self-update
}

# Install Foundry - Ethereum development framework
install_foundry() {
	# Check if foundryup is already installed
	if command_exists foundryup; then
		log_success "Foundry already installed"
		return 0
	fi

	# Download and install Foundry
	log_step "Installing Foundry..."
	if retry $RETRY_COUNT curl -L "$FOUNDRY_INSTALL_URL" | bash; then
		# Update PATH to include Foundry binaries
		if [ -d "$FOUNDRY_BIN" ]; then
			export PATH="$FOUNDRY_BIN:$PATH"
		fi

		# Run foundryup to install forge, cast, and other tools
		if command_exists foundryup; then
			foundryup
			log_success "Foundry installed successfully"
		else
			log_error "Foundry installation failed - foundryup command not found"
			exit 1
		fi
	else
		log_error "Failed to download Foundry installer"
		exit 1
	fi
}

# Install rzup - RISC Zero toolchain installer
install_rzup() {
	# Check if rzup is already installed
	if command_exists rzup; then
		log_success "rzup already installed"
		return 0
	fi

	# Download and install rzup
	log_step "Installing rzup..."
	if retry $RETRY_COUNT curl -fsSL "$RISC0_INSTALL_URL" | bash; then
		# Update PATH to include RISC0 binaries
		if [ -d "$RISC0_BIN" ]; then
			export PATH="$RISC0_BIN:$PATH"
		fi

		# Verify rzup command is available after installation
		if command_exists rzup; then
			log_success "rzup installed successfully"
		else
			log_error "rzup installation failed - command not found in PATH"
			exit 1
		fi
	else
		log_error "Failed to download rzup installer"
		exit 1
	fi
}

# Install RISC Zero toolchain - ZK proof development tools
install_risczero_toolchain() {
	# Check if cargo-risczero is already installed
	if command_exists cargo-risczero; then
		log_success "RISC Zero toolchain already installed"
		return 0
	fi

	# Install RISC Zero toolchain using rzup
	log_step "Installing RISC Zero toolchain..."
	if retry $RETRY_COUNT rzup install cargo-risczero; then
		log_success "RISC Zero toolchain installed successfully"
	else
		log_error "Failed to install RISC Zero toolchain"
		exit 1
	fi
}

# Install Noirup - Noir language toolchain manager
install_noirup() {
	# Check if noirup is already installed
	if command_exists noirup; then
		log_success "noirup already installed"
		return 0
	fi

	# Download and install noirup
	log_step "Installing noirup..."
	if retry $RETRY_COUNT curl -L "$NOIRUP_INSTALL_URL" | bash; then
		# Update PATH to include Noirup binaries
		if [ -d "$NOIRUP_BIN" ]; then
			export PATH="$NOIRUP_BIN:$PATH"
		fi

		# Initialize noirup to complete setup
		if command_exists noirup; then
			noirup
			log_success "noirup installed successfully"
		else
			log_error "noirup installation failed - noirup command not found"
			exit 1
		fi
	else
		log_error "Failed to download noirup installer"
		exit 1
	fi
}

# Install wasm-pack - WebAssembly packaging tool
install_wasm_pack() {
	# Check if wasm-pack is already installed
	if command_exists wasm-pack; then
		log_success "wasm-pack already installed"
		return 0
	fi

	# Download and install wasm-pack
	log_step "Installing wasm-pack..."
	if retry $RETRY_COUNT curl -fsSf "$WASMPACK_INSTALL_URL" | bash; then
		# Update PATH to include local binaries
		export PATH="$LOCAL_BIN:$PATH"
		
		# Verify wasm-pack command is available after installation
		if command_exists wasm-pack; then
			log_success "wasm-pack installed successfully"
		else
			log_error "wasm-pack installation failed - command not found in PATH"
			exit 1
		fi
	else
		log_error "Failed to download wasm-pack installer"
		exit 1
	fi
}

# Install solc via Homebrew
install_solc() {
	# Check if solc is already installed
	if command_exists solc; then
		log_success "solc already installed"
		return 0
	fi

	# Update Homebrew and install solc
	log_step "Installing solc via Homebrew..."
	brew update && brew upgrade && brew tap ethereum/ethereum && brew install solidity
	log_success "solc installed successfully"
}

# Install Enclave CLI - Secure execution environment framework
install_enclave() {
	# Check if enclave CLI is already installed
	if command_exists enclave; then
		log_success "Enclave CLI already installed"
		return 0
	fi

	# Install enclaveup (Enclave updater) if not present
	if ! command_exists enclaveup; then
		log_step "Installing enclaveup..."
		if retry $RETRY_COUNT curl -fsSL "$ENCLAVE_INSTALL_URL" | bash; then
			# Update PATH to include local binaries
			export PATH="$LOCAL_BIN:$PATH"

			# Search for enclaveup in alternative installation paths if not found
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

			# Verify enclaveup installation
			if command_exists enclaveup; then
				log_success "enclaveup installed successfully"
			else
				log_error "enclaveup installation failed - command not found"
				exit 1
			fi
		else
			log_error "Failed to download enclaveup installer"
			exit 1
		fi
	fi

	# Install Enclave CLI using enclaveup
	log_step "Installing Enclave CLI..."
	if retry $RETRY_COUNT enclaveup install; then
		export PATH="$LOCAL_BIN:$PATH"
		if command_exists enclave; then
			log_success "Enclave CLI installed successfully"
		else
			log_error "Enclave CLI installation failed - command not found in PATH"
			exit 1
		fi
	else
		log_error "Failed to install Enclave CLI"
		exit 1
	fi
}

# Initialize Enclave CRISP template project from Git repository
initialize_project() {
	# Check if project is already initialized (package.json exists)
	if [ -f "project/package.json" ]; then
		log_success "Enclave CRISP template project already initialized"
		return 0
	fi

	# Clone the Enclave repository with submodules
	log_step "Initializing Enclave CRISP template project..."
	if retry $RETRY_COUNT git clone $ENCLAVE_REPO_URL --recurse-submodules tmp -q; then
		# Copy repository contents to project directory
		log_step "Copying files to project directory..."
		rsync -a --ignore-existing tmp/ project/
		# Remove temporary clone directory
		rm -rf tmp
		# Set appropriate permissions for the project
		chmod -R 777 project
		log_success "Enclave CRISP template project initialized"
	else
		log_error "Failed to initialize Enclave CRISP template project"
		exit 1
	fi
}

# Prepare project dependencies and apply configuration fixes
prepare_project() {
	# Install project dependencies using pnpm
	log_step "Ensuring pnpm dependencies are installed..."
	cd project
	CI=true pnpm install --frozen-lockfile -s
	
	# Navigate to CRISP example directory and setup its dependencies
	cd $CRISP_DIR
	pnpm dev:setup
	CI=true pnpm install --frozen-lockfile -s
	cd ../..
	
	# Set correct permissions for all project files
	log_step "Ensuring permissions are set correctly..."
	chmod -R 777 .
	cd ..
}

# Start the CRISP development environment
start_project() {
	log_step "Starting development environment..."
	cd $CRISP_DIR
	pnpm dev:up
}

# Main execution function - orchestrates the entire setup process
main() {
	log_step "Setting up Enclave CRISP template development environment..."

	# Setup environment PATH for all tools
	setup_path

	# Install required development tools and dependencies
	install_foundry
	install_rzup
	install_noirup
	install_wasm_pack
	install_solc
	install_risczero_toolchain
	install_enclave

	# Initialize, prepare, and start the project
	initialize_project
	prepare_project
	start_project
}

# Run main function
main "$@"
