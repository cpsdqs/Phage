echo "Adding default cargo installation directory (~/.cargo/bin) to $PATH"
export PATH="$PATH:$HOME/.cargo/bin"

cargo build --release
