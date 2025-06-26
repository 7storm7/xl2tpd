#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration - User should customize these for CLIENT mode ---
DEFAULT_VPN_CONNECTION_NAME="myvpn"        # Matches the 'c myvpn' command. This is IMPORTANT.
DEFAULT_REMOTE_SERVER_IP="vpn.example.com" # IP or hostname of the L2TP/IPsec server
DEFAULT_VPN_USER="yourVpnUsername"         # Username for the remote VPN server
DEFAULT_VPN_PASSWORD="yourVpnPassword"     # Password for the remote VPN server

# --- PPP Configuration Details (for client connecting out) ---
# DNS servers might be provided by the remote VPN server automatically (usepeerdns).
# If not, or for fallback (though usepeerdns is preferred):
# PPP_CLIENT_DNS1="8.8.8.8"
# PPP_CLIENT_DNS2="8.8.4.4"

# --- Determine Base Output Directory ---
SCRIPT_PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONFIG_BASE_DIR="${SCRIPT_PARENT_DIR}/build_xl2tpd_android_binaries/config_on_target_CLIENT_MODE"

# --- Get user input for client mode ---
echo "--- L2TP Client Mode Configuration ---"
read -p "Enter the VPN connection name used in 'echo c <name> ...' (default: $DEFAULT_VPN_CONNECTION_NAME): " VPN_CONNECTION_NAME
VPN_CONNECTION_NAME="${VPN_CONNECTION_NAME:-$DEFAULT_VPN_CONNECTION_NAME}"

read -p "Enter remote L2TP server IP or hostname (default: $DEFAULT_REMOTE_SERVER_IP): " REMOTE_SERVER_IP
REMOTE_SERVER_IP="${REMOTE_SERVER_IP:-$DEFAULT_REMOTE_SERVER_IP}"

read -p "Enter your VPN username for '$REMOTE_SERVER_IP' (default: $DEFAULT_VPN_USER): " VPN_USER
VPN_USER="${VPN_USER:-$DEFAULT_VPN_USER}"

read -s -p "Enter your VPN password for '$REMOTE_SERVER_IP' (default: $DEFAULT_VPN_PASSWORD): " VPN_PASSWORD_INPUT
VPN_PASSWORD="${VPN_PASSWORD_INPUT:-$DEFAULT_VPN_PASSWORD}"
echo # Newline after password input

# --- Create directory structure ---
ETC_DIR="${TARGET_CONFIG_BASE_DIR}/etc_replacement_for_target"
XL2TPD_CONF_DIR="${ETC_DIR}/xl2tpd" # xl2tpd config dir
PPP_CONF_DIR="${ETC_DIR}/ppp"       # ppp related files dir

mkdir -p "$XL2TPD_CONF_DIR"
mkdir -p "$PPP_CONF_DIR"

echo ""
echo "L2TP Client configuration files will be generated in: $TARGET_CONFIG_BASE_DIR"
echo "You will use a command like 'echo \"c $VPN_CONNECTION_NAME\" > /data/local/tmp/l2tp-control' on the target."
echo "Ensure xl2tpd is configured to use this control file path."
echo ""

# --- Define TARGET paths (where files would reside ON THE TARGET DEVICE) ---
TARGET_BASE_CONF_PATH_ON_DEVICE="/data/local/tmp/my_xl2tpd_client_configs" # EXAMPLE
# The PPP options file MUST match the name given in xl2tpd.conf's pppoptfile
TARGET_PPP_OPTIONS_FILE_PATH="${TARGET_BASE_CONF_PATH_ON_DEVICE}/ppp/options.${VPN_CONNECTION_NAME}"
TARGET_CHAP_SECRETS_FILE_PATH="${TARGET_BASE_CONF_PATH_ON_DEVICE}/ppp/chap-secrets"
# xl2tpd control file path (as you used it)
XL2TPD_CONTROL_FILE_ON_TARGET="/data/local/tmp/l2tp-control" # Ensure xl2tpd is started with this control path if not default

# --- 1. Create xl2tpd.conf (for CLIENT mode) ---
XL2TPD_CONF_FILE_LOCAL="${XL2TPD_CONF_DIR}/xl2tpd.conf"
echo "Creating L2TP Client config: $XL2TPD_CONF_FILE_LOCAL ..."
cat > "$XL2TPD_CONF_FILE_LOCAL" << EOF
[global]
; access control = no ; 'no' is typical for client mode.
; auth file = $TARGET_CHAP_SECRETS_FILE_PATH ; pppd usually finds chap-secrets on its own or via options file
; debug avp = yes
; debug network = yes
; debug state = yes
; debug tunnel = yes

; This 'lac' section name MUST match the name you use in the 'echo "c <name>"' command
[lac $VPN_CONNECTION_NAME]
lns = $REMOTE_SERVER_IP             ; IP address or hostname of the LNS (remote L2TP server).
pppoptfile = $TARGET_PPP_OPTIONS_FILE_PATH ; Path to the pppd options file for this connection.
                                    ; CRITICAL: pppd must find this on the target.
; redial = yes                      ; Automatically redial if the connection drops.
; redial timeout = 15               ; Seconds to wait before redialing.
; max redials = 0                   ; Maximum number of redial attempts (0 for infinite).
                                    ; Use with caution.
; require chap = yes                ; Client will offer CHAP; server dictates if it's required.
; require authentication = yes      ; Client will authenticate; server requires it.
; name = $VPN_USER                  ; Alternative to pppd 'user' option, less common.
EOF

# --- 2. Create PPP options file (for CLIENT connecting out) ---
PPP_OPTIONS_FILE_LOCAL="${PPP_CONF_DIR}/options.${VPN_CONNECTION_NAME}" # Filename matches 'pppoptfile' in xl2tpd.conf
echo "Creating PPP Client options: $PPP_OPTIONS_FILE_LOCAL ..."
cat > "$PPP_OPTIONS_FILE_LOCAL" << EOF
# PPP options for L2TP client connection: $VPN_CONNECTION_NAME
# Referenced by xl2tpd.conf's 'pppoptfile' for the '$VPN_CONNECTION_NAME' LAC.

# Essential Client Options:
noipdefault             # Don't use the client's local IP, obtain from server.
usepeerdns              # IMPORTANT: Obtain DNS server addresses from the remote PPP server.
defaultroute            # Add default route through this PPP interface once connected.
persist                 # Keep trying to connect even if initial attempts fail or connection drops.
                        # Combine with 'maxfail' or xl2tpd's redial options.
# maxfail 0             # Try indefinitely to connect (use with caution, especially on mobile data).
holdoff 10              # Wait 10 seconds between connection attempts if persist is used.

# Authentication:
# User name for authentication on the remote server.
# This MUST match an entry in your $TARGET_CHAP_SECRETS_FILE_PATH
user "$VPN_USER"
# refuse-pap            # Don't offer PAP authentication (less secure).
# refuse-chap           # If you only want to use MS-CHAPv2 (server must support it).
require-mschap-v2       # Prefer/require MS-CHAPv2 if the server supports it (more secure).
# require-chap          # Fallback if MS-CHAPv2 is not an option.

# Security/Encryption (MPPE is often used with MS-CHAPv2):
# nomppe                # Disable MPPE if not needed or causing issues.
# require-mppe          # Require MPPE encryption.
# require-mppe-128      # Require 128-bit MPPE. Server must support.

# MTU/MRU Settings to avoid fragmentation, especially over L2TP/IPsec
mtu 1280                # Max Transmission Unit for outgoing packets.
mru 1280                # Max Receive Unit for incoming packets.

# Compression (usually best to disable unless specifically needed and tested)
# nobsdcomp
# nodeflate
# novj
# novjccomp

# Logging/Debugging for pppd (can be verbose)
# debug                 # Enable pppd debugging.
# logfd 2               # Log to stderr (useful if running pppd from a script that captures output).
# logfile ${TARGET_BASE_CONF_PATH_ON_DEVICE}/ppp-${VPN_CONNECTION_NAME}.log # Log to a file (ensure path is writable).

# Other options
# connect /bin/true     # Dummy connect script if needed by some pppd versions (rarely).
# nodetach              # Don't detach from terminal (useful for debugging pppd startup).
# updetach              # Detach after connection is up.
# ipcp-accept-local     # Accept server's idea of our local IP even if we suggested one.
# ipcp-accept-remote    # Accept server's idea of its remote IP.
# lcp-echo-interval 30  # Send LCP echo requests every 30 seconds to keep connection alive.
# lcp-echo-failure 4    # Consider link down after 4 failed LCP echos.
EOF

# --- 3. Create chap-secrets (for CLIENT mode) ---
# This file stores the client's credentials for authenticating TO THE REMOTE SERVER.
CHAP_SECRETS_FILE_LOCAL="${PPP_CONF_DIR}/chap-secrets"
echo "Creating CHAP secrets for Client: $CHAP_SECRETS_FILE_LOCAL ..."
# Note: The path used by pppd on the target for chap-secrets is often a compiled-in default
# like /etc/ppp/chap-secrets or can be specified in pppd options.
# Here, we generate it into our structure, and you must ensure pppd on target can find it,
# either by placing it in the expected default path (if writable and appropriate)
# or by configuring pppd. The 'authfile' option in pppd's options file can also specify this.
cat > "$CHAP_SECRETS_FILE_LOCAL" << EOF
# Secrets for CHAP and MS-CHAP authentication for pppd (Client Mode)
# Used when this Android device connects as a client to a remote L2TP server.
#
# Format:
# <our_username_for_server> <server_name_or_*> <our_password_for_server> <our_local_IP_or_*>
#
# The 'our_username_for_server' MUST match the 'user "$VPN_USER"' option in the
# corresponding PPP options file (e.g., options.$VPN_CONNECTION_NAME).
#
# The 'server_name_or_*' can be:
#   '*' : to match any server name presented by the remote LNS.
#   A specific server name: if the remote LNS presents a specific "name" during LCP negotiation
#                          and you want to tie these credentials to that specific server name.
#                          (e.g., if remote server is 'RemoteLNS1')
#
# The 'our_password_for_server' is the secret password for the $VPN_USER account on the remote LNS.
#
# The 'our_local_IP_or_*' can be:
#   '*' : to allow any local IP address to be assigned by the server. (Most common for clients)
#   A specific IP: if you want to request a specific IP from the server (server must allow this).

"$VPN_USER"    *    "$VPN_PASSWORD"    *
# Example if server name was specific:
# "$VPN_USER"    "NameOfRemoteL2TPServer"    "$VPN_PASSWORD"    *
EOF

# --- Item 4: Create an informational file for CLIENT mode setup on target ---
INFO_FILE_LOCAL="${TARGET_CONFIG_BASE_DIR}/client_mode_setup_info_ON_TARGET.txt"
echo "Creating Client Mode setup info: $INFO_FILE_LOCAL ..."
cat > "$INFO_FILE_LOCAL" << EOF
This file provides guidance for setting up and running xl2tpd in CLIENT MODE
on the Android target device.

*******************************************************************************
*** L2TP Client Mode - Android Device Connects OUT to a Remote L2TP Server  ***
*******************************************************************************

Configuration Files Overview (to be pushed to target, e.g., to '$TARGET_BASE_CONF_PATH_ON_DEVICE'):
1.  xl2tpd.conf:
    - Contains the [global] section.
    - Contains one or more [lac $VPN_CONNECTION_NAME] sections, each defining a connection
      to a remote L2TP server (LNS). The section name (e.g., "$VPN_CONNECTION_NAME") is used
      to initiate the connection via the control file.
    - Path on target (example): $TARGET_BASE_CONF_PATH_ON_DEVICE/xl2tpd/xl2tpd.conf

2.  options.$VPN_CONNECTION_NAME (PPP Options File):
    - One per [lac ...] section, named to match the 'pppoptfile' directive in xl2tpd.conf.
    - Contains pppd settings for the outgoing client connection (user, auth methods, DNS, routes).
    - Path on target (example): $TARGET_BASE_CONF_PATH_ON_DEVICE/ppp/options.$VPN_CONNECTION_NAME

3.  chap-secrets:
    - Stores the username/password credentials used by this Android client to
      authenticate itself TO THE REMOTE L2TP SERVER.
    - Path on target (example): $TARGET_BASE_CONF_PATH_ON_DEVICE/ppp/chap-secrets
      (pppd needs to be able to find this. If not in a default pppd path, ensure pppd is configured
       to look here, possibly via an 'authfile' directive in the options file, though often pppd
       checks its default /etc/ppp/chap-secrets or a path relative to its execution).

Deployment and Execution Steps on Target Android Device (usually via 'adb shell' with root):

A. Push Configuration Files:
   Push the contents of the generated '${ETC_DIR}' directory (which contains 'xl2tpd'
   and 'ppp' subdirectories) to your chosen base configuration path on the target.
   Example using your chosen target base path '$TARGET_BASE_CONF_PATH_ON_DEVICE':
   adb push "${ETC_DIR}/." "$TARGET_BASE_CONF_PATH_ON_DEVICE/"

   This should create files like:
     $TARGET_BASE_CONF_PATH_ON_DEVICE/xl2tpd/xl2tpd.conf
     $TARGET_BASE_CONF_PATH_ON_DEVICE/ppp/options.$VPN_CONNECTION_NAME
     $TARGET_BASE_CONF_PATH_ON_DEVICE/ppp/chap-secrets

B. Ensure xl2tpd and pppd Paths and Permissions:
   - Make sure your cross-compiled 'xl2tpd' and 'pppd' binaries are on the Android device
     (e.g., in /data/local/tmp/) and are executable (\`chmod +x /data/local/tmp/xl2tpd\` \`chmod +x /data/local/tmp/pppd\`).
   - xl2tpd needs to be able to read its config file and write to its control file (if not using /var/run default).
   - pppd (called by xl2tpd) needs to read its options file and the chap-secrets file.

C. Start xl2tpd Daemon:
   Run your cross-compiled xl2tpd binary. It's often best to run it in the foreground
   with debugging initially to see logs.
   Example (ensure paths to binary, config, and control file are correct):

   /data/local/tmp/xl2tpd \\
     -c $TARGET_BASE_CONF_PATH_ON_DEVICE/xl2tpd/xl2tpd.conf \\
     -C $XL2TPD_CONTROL_FILE_ON_TARGET \\
     -D

   Flags:
     -c /path/to/xl2tpd.conf   : Specifies the configuration file.
     -C /path/to/control_file  : Specifies the control file path.
                                  This MUST match the path you use with 'echo "c..."'.
     -D                        : Run in foreground with debug output to stdout/stderr.
                                  Remove for background operation once tested.

D. Initiate the L2TP Connection:
   Once xl2tpd is running and listening to its control file, open another 'adb shell' or use '&'
   to background the daemon, then send the connect command to the control file.
   The connection name ('$VPN_CONNECTION_NAME' in this example) MUST match a [lac <name>]
   section in your xl2tpd.conf.

   echo "c $VPN_CONNECTION_NAME" > $XL2TPD_CONTROL_FILE_ON_TARGET

   Example: echo "c myvpn" > /data/local/tmp/l2tp-control

E. Check Connection Status & Logs:
   - Look at the debug output of xl2tpd (if running with -D).
   - After connection, a 'ppp0' (or similar) interface should appear. Check with:
     ip addr show ppp0
     ifconfig ppp0
   - Check routing table to see if a default route via ppp0 is added (if 'defaultroute' in PPP options):
     ip route
   - Test connectivity:
     ping -I ppp0 8.8.8.8  # Or ping an IP on the remote VPN network
   - pppd logs: If you configured a log file in the PPP options file (e.g., options.$VPN_CONNECTION_NAME),
     check that file for pppd specific messages. Example:
     # logfile ${TARGET_BASE_CONF_PATH_ON_DEVICE}/ppp-${VPN_CONNECTION_NAME}.log (in options file)
     Then on device: cat $TARGET_BASE_CONF_PATH_ON_DEVICE/ppp-${VPN_CONNECTION_NAME}.log

F. Disconnect:
   To disconnect the specific L2TP session:
   echo "d $VPN_CONNECTION_NAME" > $XL2TPD_CONTROL_FILE_ON_TARGET

   To shut down the xl2tpd daemon (if running in background):
   Find its PID (ps -ef | grep xl2tpd or pgrep xl2tpd) and then 'kill <PID>'.
   If it was started with -C and supports it, you can also try:
   echo "shutdown" > $XL2TPD_CONTROL_FILE_ON_TARGET (This might not always work reliably)

IPsec Note:
This setup assumes L2TP is running either standalone (unencrypted, not recommended over public internet)
or that L2TP is running over an IPsec tunnel that is established SEPARATELY (e.g., by strongSwan
or another IPsec daemon on the Android device). This script system DOES NOT configure IPsec.
If IPsec is required for your connection, the IPsec tunnel must be established *first*
between the Android device and the remote server. xl2tpd then runs L2TP *inside* that
already established secure IPsec tunnel. The 'lns = <server_ip>' in your xl2tpd.conf
would typically be the remote server's private IP address at the other end of the IPsec
tunnel, or its public IP if IPsec is in transport mode and xl2tpd is configured to
bind to the IPsec-protected traffic. This script system does not set up IPsec.

EOF
# End of the cat command for INFO_FILE_LOCAL

echo ""
echo "--- L2TP Client Configuration Generation Complete ---"
echo "Generated files are in: $TARGET_CONFIG_BASE_DIR"
echo "Remember to:"
echo "1. Push the contents of '${ETC_DIR}' (which contains 'xl2tpd' and 'ppp' subdirectories)"
echo "   to your chosen base configuration path on the target Android device."
echo "   Example: adb push \"${ETC_DIR}/.\" \"$TARGET_BASE_CONF_PATH_ON_DEVICE/\""
echo "2. Ensure your xl2tpd and pppd binaries on the target are configured/called to use these"
echo "   specific file paths for their configurations."
echo "3. Follow the instructions in '${INFO_FILE_LOCAL}' to deploy and run xl2tpd in client mode,"
echo "   and how to initiate connections using the control file (e.g., '$XL2TPD_CONTROL_FILE_ON_TARGET')."

# Go back to the script's original directory before exiting (if SCRIPT_PARENT_DIR was defined and used)
# Assuming SCRIPT_PARENT_DIR was defined at the beginning of the full script:
# cd "$SCRIPT_PARENT_DIR"
exit 0
