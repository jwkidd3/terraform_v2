#!/usr/bin/env bash
# setup.sh - Prepare a Cloud9 environment for the Terraform course.
#
# Usage:
#   bash ~/environment/terraform_v2/lab-exercises/lab01/setup.sh <username>
#   source ~/.bashrc
#
# What it does (safe to re-run):
#   1. Grows the Cloud9 root EBS volume to 100 GB and extends the filesystem.
#      The resize happens online while Cloud9 keeps running: no reboot needed.
#   2. Installs Terraform (pinned), unzip, jq, git, and Docker
#   3. Starts Docker and grants the current user access to it
#   4. Saves TF_VAR_username to ~/.bashrc
#
# Instructor notes:
#   - The resize needs ec2:DescribeInstances, ec2:DescribeVolumes,
#     ec2:ModifyVolume and ec2:DescribeVolumesModifications on the Cloud9
#     instance's credentials. If any of these is denied (or fails), the script
#     prints a warning and carries on: the tools are still installed and the
#     username is still saved. It still runs growpart/xfs_growfs so a disk that
#     was resized in the console is picked up.
#   - At the end of step 1 the size of / is compared with TARGET_SIZE_GB; if it
#     is still below 90% of the target a warning (not a check mark) is printed.
#     Re-running the script a minute later normally fixes it.
#   - An EBS volume can only be modified about once every 6 hours, so a failed
#     resize may need the volume enlarged in the EC2 console instead.
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

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
AWS_ERR="$TMP_DIR/aws-error.txt"
# Last line of the most recent AWS CLI error, for warning messages
aws_error() { tail -1 "$AWS_ERR" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# 1. Grow the root volume (online: no reboot needed)
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

# Look up the root volume. If the EC2 API calls are denied or fail, skip the
# EBS resize (CAN_RESIZE=false) instead of aborting the whole script.
CAN_RESIZE=false
VOLUME_ID=""
CURRENT_SIZE=""
if ROOT_DEVICE=$(aws ec2 describe-instances --region "$EC2_REGION" --instance-ids "$INSTANCE_ID" \
       --query 'Reservations[0].Instances[0].RootDeviceName' --output text 2>"$AWS_ERR") \
   && VOLUME_ID=$(aws ec2 describe-instances --region "$EC2_REGION" --instance-ids "$INSTANCE_ID" \
       --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='$ROOT_DEVICE'].Ebs.VolumeId" \
       --output text 2>"$AWS_ERR") \
   && [[ "$VOLUME_ID" == vol-* ]] \
   && CURRENT_SIZE=$(aws ec2 describe-volumes --region "$EC2_REGION" --volume-ids "$VOLUME_ID" \
       --query 'Volumes[0].Size' --output text 2>"$AWS_ERR") \
   && [[ "$CURRENT_SIZE" =~ ^[0-9]+$ ]]; then
  CAN_RESIZE=true
else
  warn "Could not look up the root EBS volume (ec2:DescribeInstances/DescribeVolumes denied?)."
  [[ -s "$AWS_ERR" ]] && warn "AWS said: $(aws_error)"
  warn "Skipping the volume resize; the filesystem will still be extended to fill the current disk."
fi

if [[ "$CAN_RESIZE" == true ]]; then
  if (( CURRENT_SIZE >= TARGET_SIZE_GB )); then
    ok "Volume $VOLUME_ID is already ${CURRENT_SIZE} GB"
  elif aws ec2 modify-volume --region "$EC2_REGION" --volume-id "$VOLUME_ID" \
         --size "$TARGET_SIZE_GB" >/dev/null 2>"$AWS_ERR"; then
    ok "Requested resize of $VOLUME_ID: ${CURRENT_SIZE} GB -> ${TARGET_SIZE_GB} GB"
    # The filesystem can be extended once the modification reaches
    # 'optimizing' (or 'completed'); this normally takes under a minute.
    STATE=unknown
    for _ in $(seq 1 60); do
      if ! STATE=$(aws ec2 describe-volumes-modifications --region "$EC2_REGION" \
             --volume-ids "$VOLUME_ID" --query 'VolumesModifications[0].ModificationState' \
             --output text 2>"$AWS_ERR"); then
        STATE=query-failed
        break
      fi
      [[ "$STATE" == "optimizing" || "$STATE" == "completed" ]] && break
      sleep 5
    done
    case "$STATE" in
      optimizing|completed)
        ok "Volume modification state: $STATE" ;;
      query-failed)
        warn "Cannot confirm the resize progress (ec2:DescribeVolumesModifications denied?)."
        [[ -s "$AWS_ERR" ]] && warn "AWS said: $(aws_error)"
        warn "Waiting 30 seconds, then extending the filesystem anyway."
        sleep 30 ;;
      *)
        warn "Volume modification is still '$STATE' after 5 minutes; extending the filesystem anyway." ;;
    esac
  else
    warn "Could not resize the volume (ec2:ModifyVolume denied?). Ask your instructor."
    [[ -s "$AWS_ERR" ]] && warn "AWS said: $(aws_error)"
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

# Check the result: / should now be close to TARGET_SIZE_GB (a 100 GB volume
# shows as ~100G in df). Anything under 90% of the target means the resize
# did not take effect (yet).
ROOT_SIZE_GB=$(df -Pk / | awk 'NR==2 {printf "%d", $2 / 1048576}')
ROOT_SUMMARY=$(df -h / | awk 'NR==2 {print $2 " total, " $4 " free"}')
if (( ROOT_SIZE_GB * 10 < TARGET_SIZE_GB * 9 )); then
  DISK_OK=false
  warn "Root filesystem is only ${ROOT_SIZE_GB} GB (${ROOT_SUMMARY}); expected about ${TARGET_SIZE_GB} GB."
  warn "Re-run this script in a minute. If it stays small, ask your instructor."
else
  DISK_OK=true
  ok "Root filesystem: ${ROOT_SUMMARY}"
fi

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
if ! sudo systemctl enable --now docker >/dev/null 2>&1; then
  # Fallback for images without systemd as PID 1
  if command -v service >/dev/null 2>&1; then
    sudo service docker start >/dev/null 2>&1 || true
  fi
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  warn "Added $USER to the docker group: open a NEW terminal tab before using docker"
fi
if DOCKER_VERSION=$(sudo docker version --format '{{.Server.Version}}' 2>/dev/null); then
  ok "Docker $DOCKER_VERSION is running"
else
  DOCKER_VERSION="not running"
  warn "Docker did not start. Try: sudo systemctl start docker   (then re-run this script)"
fi

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
  "Docker:"    "$DOCKER_VERSION" \
  "AWS CLI:"   "$(aws --version 2>&1 | cut -d' ' -f1)" \
  "Git:"       "$(git --version | cut -d' ' -f3)"
if [[ "$DISK_OK" == true ]]; then
  printf '\n    The disk was resized online: no reboot is needed.\n'
else
  printf '\n    \033[33mThe disk is still smaller than %s GB: see the warning above and re-run this script.\033[0m\n' "$TARGET_SIZE_GB"
  printf '    (A reboot does not help; the resize happens online.)\n'
fi
printf '\n    Now run:  \033[1msource ~/.bashrc\033[0m\n\n'
