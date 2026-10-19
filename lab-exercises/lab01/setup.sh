#!/usr/bin/env bash
# setup.sh - Prepare a Cloud9 environment for the Terraform course.
#
# Usage:
#   bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <username>
#   source ~/.bashrc
#
# What it does (safe to re-run):
#   1. Grows the Cloud9 root EBS volume to 100 GB and extends the filesystem
#   2. Installs Terraform (pinned), unzip, jq, git, and Docker
#   3. Starts Docker and grants the current user access to it
#   4. Saves TF_VAR_username to ~/.bashrc
#
# Environment overrides:
#   TARGET_SIZE_GB      volume size in GB (default 100)
#   TERRAFORM_VERSION   Terraform version (default 1.9.8)

set -euo pipefail

TARGET_SIZE_GB="${TARGET_SIZE_GB:-100}"
TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.9.8}"
USERNAME="${1:-${TF_VAR_username:-}}"

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 0. Validate the username first so a typo fails fast
# ---------------------------------------------------------------------------
if [[ -z "$USERNAME" ]]; then
  die "No username given. Run: bash $0 <your-assigned-username>   (e.g. user1)"
fi
if [[ ! "$USERNAME" =~ ^[a-z0-9-]{3,20}$ ]]; then
  die "Username '$USERNAME' is invalid: use 3-20 lowercase letters, numbers, or hyphens."
fi

if command -v dnf >/dev/null 2>&1; then PKG=dnf; else PKG=yum; fi

# ---------------------------------------------------------------------------
# 1. Grow the root volume
# ---------------------------------------------------------------------------
info "Resizing root volume to ${TARGET_SIZE_GB} GB"

# IMDSv2: request a session token, then read instance metadata with it
IMDS_TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300") \
  || die "Cannot reach instance metadata. Is this running on the Cloud9 EC2 instance?"
imds() { curl -sf -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }

INSTANCE_ID=$(imds instance-id)
# The Cloud9 instance lives in us-east-1; always query its own region,
# regardless of where the labs deploy.
EC2_REGION=$(imds placement/region)

ROOT_DEVICE=$(aws ec2 describe-instances --region "$EC2_REGION" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].RootDeviceName' --output text)
VOLUME_ID=$(aws ec2 describe-instances --region "$EC2_REGION" --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='$ROOT_DEVICE'].Ebs.VolumeId" \
  --output text)
CURRENT_SIZE=$(aws ec2 describe-volumes --region "$EC2_REGION" --volume-ids "$VOLUME_ID" \
  --query 'Volumes[0].Size' --output text)

if (( CURRENT_SIZE >= TARGET_SIZE_GB )); then
  ok "Volume $VOLUME_ID is already ${CURRENT_SIZE} GB"
else
  if aws ec2 modify-volume --region "$EC2_REGION" --volume-id "$VOLUME_ID" \
       --size "$TARGET_SIZE_GB" >/dev/null; then
    ok "Requested resize of $VOLUME_ID: ${CURRENT_SIZE} GB -> ${TARGET_SIZE_GB} GB"
    # The filesystem can be extended once the modification reaches
    # 'optimizing' (or 'completed'); this normally takes under a minute.
    for _ in $(seq 1 60); do
      STATE=$(aws ec2 describe-volumes-modifications --region "$EC2_REGION" \
        --volume-ids "$VOLUME_ID" --query 'VolumesModifications[0].ModificationState' \
        --output text 2>/dev/null || echo unknown)
      [[ "$STATE" == "optimizing" || "$STATE" == "completed" ]] && break
      sleep 5
    done
    [[ "$STATE" == "optimizing" || "$STATE" == "completed" ]] \
      || die "Volume modification still '$STATE' after 5 minutes. Wait, then re-run this script."
    ok "Volume modification state: $STATE"
  else
    warn "Could not resize the volume (ec2:ModifyVolume denied?). Ask your instructor."
    warn "Continuing with the current ${CURRENT_SIZE} GB disk."
  fi
fi

# Extend the partition and filesystem to fill the disk. Works for both
# NVMe (m5: /dev/nvme0n1p1) and Xen (t2: /dev/xvda1) device names.
ROOT_SOURCE=$(findmnt -n -o SOURCE /)
ROOT_FSTYPE=$(findmnt -n -o FSTYPE /)
PART_FILE="/sys/class/block/$(basename "$ROOT_SOURCE")/partition"

if [[ -f "$PART_FILE" ]]; then
  PARENT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_SOURCE" | head -1)"
  command -v growpart >/dev/null 2>&1 || sudo "$PKG" install -y -q cloud-utils-growpart >/dev/null
  # growpart exits 1 with "NOCHANGE" when the partition already fills the disk
  sudo growpart "$PARENT_DISK" "$(cat "$PART_FILE")" >/dev/null 2>&1 || true
fi

case "$ROOT_FSTYPE" in
  xfs)  sudo xfs_growfs -d / >/dev/null ;;
  ext4) sudo resize2fs "$ROOT_SOURCE" >/dev/null ;;
  *)    warn "Unknown filesystem '$ROOT_FSTYPE'; not extended" ;;
esac
ok "Root filesystem: $(df -h / | awk 'NR==2 {print $2 " total, " $4 " free"}')"

# ---------------------------------------------------------------------------
# 2. Install tools
# ---------------------------------------------------------------------------
info "Installing packages (unzip, jq, git, docker)"
sudo "$PKG" install -y -q unzip jq git >/dev/null
# Cloud9 images ship with Docker; install it only if it's missing
command -v docker >/dev/null 2>&1 || sudo "$PKG" install -y -q docker >/dev/null \
  || die "Docker is not installed and could not be installed with $PKG"
ok "Packages installed"

info "Installing Terraform ${TERRAFORM_VERSION}"
if command -v terraform >/dev/null 2>&1 \
   && terraform version | head -1 | grep -q "v${TERRAFORM_VERSION}$"; then
  ok "Terraform ${TERRAFORM_VERSION} already installed"
else
  case "$(uname -m)" in
    x86_64)  TF_ARCH=amd64 ;;
    aarch64) TF_ARCH=arm64 ;;
    *)       die "Unsupported architecture: $(uname -m)" ;;
  esac
  TF_ZIP="terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip"
  TF_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  curl -sSfL -o "$TMP_DIR/$TF_ZIP" "$TF_URL/$TF_ZIP"
  curl -sSfL -o "$TMP_DIR/SHA256SUMS" "$TF_URL/terraform_${TERRAFORM_VERSION}_SHA256SUMS"
  (cd "$TMP_DIR" && grep " ${TF_ZIP}\$" SHA256SUMS | sha256sum -c --quiet -) \
    || die "Terraform download failed checksum verification"
  sudo unzip -o -q "$TMP_DIR/$TF_ZIP" terraform -d /usr/local/bin/
  ok "Installed $(terraform version | head -1)"
fi

# ---------------------------------------------------------------------------
# 3. Docker
# ---------------------------------------------------------------------------
info "Configuring Docker"
sudo systemctl enable --now docker >/dev/null 2>&1 || sudo service docker start >/dev/null
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  warn "Added $USER to the docker group: open a NEW terminal tab before using docker"
fi
ok "$(sudo docker version --format 'Docker {{.Server.Version}} is running')"

# ---------------------------------------------------------------------------
# 4. Persist the username
# ---------------------------------------------------------------------------
info "Saving TF_VAR_username=${USERNAME} to ~/.bashrc"
touch ~/.bashrc
sed -i '/^export TF_VAR_username=/d' ~/.bashrc
echo "export TF_VAR_username=\"${USERNAME}\"" >> ~/.bashrc
ok "Saved (replaces any earlier TF_VAR_username line)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
info "Setup complete"
printf '    %-12s %s\n' \
  "Username:"  "$USERNAME" \
  "Disk:"      "$(df -h / | awk 'NR==2 {print $2}')" \
  "Terraform:" "$(terraform version | head -1)" \
  "Docker:"    "$(sudo docker version --format '{{.Server.Version}}')" \
  "AWS CLI:"   "$(aws --version 2>&1 | cut -d' ' -f1)" \
  "Git:"       "$(git --version | cut -d' ' -f3)"
printf '\n    Now run:  \033[1msource ~/.bashrc\033[0m\n\n'
