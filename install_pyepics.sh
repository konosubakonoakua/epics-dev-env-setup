command -v uv >/dev/null 2>&1 || { echo "uv not found, installing..."; curl -LsSf https://astral.sh/uv/install.sh | sh; }
mkdir -p /home/$USER/.config/uv
cat > /home/$USER/.config/uv/uv.toml << 'EOF'
index-url = "https://mirrors.bfsu.edu.cn/pypi/web/simple"
EOF

mkdir -p /opt/epics/python_versions
export UV_PYTHON_INSTALL_DIR="/opt/epics/python_versions"
export PCAS="/opt/epics/synApps/support/pcas-v4-13-3/"

uv pip install msgpack protobuf pyzmq fabric
uv pip install pyvisa pyvisa-py pyvisa-sim
uv pip install pyserial smbus3 spidev
uv pip install caproto pcaspy softioc pyepics
uv pip install fastapi[standard] flask
uv pip install matplotlib seaborn plotly pandas scipy jupyterlab nicegui
