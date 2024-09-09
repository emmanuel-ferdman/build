variable "orka_endpoint" {
  type    = string
  default = ""
}

variable "orka_auth_token" {
  type    = string
  default = ""
}

variable "ssh_default_username" {
  type    = string
  default = ""
}

variable "ssh_default_password" {
  type    = string
  default = ""
}

variable "ssh_release_public_key" {
  type    = string
  default = ""
}

variable "ssh_release_password" {
  type    = string
  default = ""
}

packer {
  required_plugins {
    macstadium-orka = {
      version = "~> 3.0"
      source  = "github.com/macstadium/macstadium-orka"
    }
  }
}

source "macstadium-orka" "macos13-arm-release-image" {
  source_image      = "macos13-arm-release-base.orkasi"
  image_name        = "macos13-arm-release-latest.orkasi"
  image_description = "The MacOS 13 ARM release image"
  orka_endpoint     = var.orka_endpoint
  orka_auth_token   = var.orka_auth_token
  ssh_username      = var.ssh_default_username
  ssh_password      = var.ssh_release_password
}

build {
  sources = [
    "macstadium-orka.macos13-arm-release-image"
  ]

  // Add SSH key access.
  provisioner "shell" {
    inline = [
      "echo 'Adding SSH key access...'",
      "mkdir -p /Users/${var.ssh_default_username}/.ssh",
      "echo '${var.ssh_release_public_key}' >> /Users/${var.ssh_default_username}/.ssh/authorized_keys",
      "chown -R ${var.ssh_default_username}:staff /Users/${var.ssh_default_username}/.ssh",
      "chmod 700 /Users/${var.ssh_default_username}/.ssh",
      "chmod 600 /Users/${var.ssh_default_username}/.ssh/authorized_keys"
    ]
  } 

  // Disable SSH password authentication.
  // @TODO: Review fallback to password authentication.
  provisioner "shell" {
    inline = [
      "echo 'Disabling SSH password authentication...'",
      "sudo sed -i '' 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config",
      "sudo sed -i '' 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config",
      "sudo sed -i '' 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config",
      "sudo sed -i '' 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config",
      "sudo systemsetup -f -setremotelogin on",
      "sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist",
      "sudo launchctl load /System/Library/LaunchDaemons/ssh.plist",
    ]
  }

  // Install Homebrew.
  provisioner "shell" {
    inline = [
      "echo 'Installing Homebrew...'",
      "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "(echo; echo 'eval \"$($(brew --prefix)/bin/brew shellenv)\"') >> /Users/admin/.zprofile",
      "eval \"$($(brew --prefix)/bin/brew shellenv)\""
    ]
  }
  // Check Homebrew. Ignore errors because we are not using the last version of Xcode.
  provisioner "shell" {
    inline = [
      "echo 'Checking Homebrew...'",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "/opt/homebrew/bin/brew doctor || true"
    ]
  }
  // Install dependencies for build and release.
  provisioner "shell" {
    inline = [
      "echo 'Installing packages using Homebrew...'",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "/opt/homebrew/bin/brew install git automake bash libtool cmake python ccache"
    ]
  }
  // Install Java 17 for Jenkins.
  provisioner "shell" {
    inline = [
      "echo 'Installing JRE...'",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "/opt/homebrew/bin/brew install --cask temurin@17",
    ]
  }
  // Print the version of the installed packages.
  provisioner "shell" {
    inline = [
      "echo 'Printing the version of the installed packages...'",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "/opt/homebrew/bin/brew list --versions",
      "java -version"
    ]
  }
}