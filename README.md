# enclave-crisp-template

One-liner to auto-install & run (& dev) a `fdevc runnable project` for [Enclave CRISP template](https://github.com/gnosisguild/enclave/tree/main/examples/CRISP) powered by [fdevc](https://github.com/philogicae/fast_dev_container)

[![Curl](https://img.shields.io/badge/curl-required-orange)](https://curl.se/)
[![Git](https://img.shields.io/badge/git-required-orange)](https://git-scm.com/)
[![Docker](https://img.shields.io/badge/docker-required-orange)](https://www.docker.com/get-started/)
[![Python](https://img.shields.io/badge/python-3.10%2B-blue)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/philogicae/enclave-crisp-template)

> Docs: [Enclave CRISP](https://docs.enclave.gg/CRISP/introduction)

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/philogicae/enclave-crisp-template/main/install_and_run | bash
```

![banner](banner.png)

## Project Structure

```
📁 enclave-crisp-template
 ├── install_and_run       # Auto-install script
 ├── launch.sh              # Container launcher
 ├── 📁 project             # Git project mount
 └── 📁 fdevc_setup          # Setup scripts mount
      └── runnable.sh         # Main container script
```

- **`install_and_run`** - Installation script that ensures `fdevc` is available, clones this repository, and runs `launch.sh`.
- **`launch.sh`** - Helper script to launch a container using `fdevc` with predefined settings. Edit the configuration variables at the top to customize ports, image, persistence, etc.
- **`fdevc_setup/runnable.sh`** - The main script that runs inside the container (complete Enclave setup).
- **`project/`** - The mounted target folder for git cloned project

## Usage

> Required: enclave-crisp-template is running (quick install script or ran ./launch.sh directly)

1. Add Anvil (Hardhat Local Network) to your browser wallet extension (e.g. [MetaMask](https://metamask.io/), [Rabby](https://rabby.io/), etc):

```bash
Network Name: Anvil (or Localhost)
RPC URL: http://127.0.0.1:8545 (or any other forwarded port you configured)
Chain ID: 31337
Currency Symbol: ETH
Block Explorer URL: (Optional) Leave blank
```

2. For testing, add any Hardhat pre-funded account to your browser wallet extension:

```bash
Account #0: 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 (10000 ETH)
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Account #1: 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 (10000 ETH)
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

Account #2: 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc (10000 ETH)
Private Key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
```

3. Try out Enclave template at [http://localhost:3000](http://localhost:3000) (or any other forwarded port you configured)

4. Open `enclave-crisp-template` in your IDE and start coding!
