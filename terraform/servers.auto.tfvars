servers = {
  lobby = { region = "us-east", tags = ["lobby"], destroy = true }
  # Servers can be deleted in two ways: (1) by removing the server line or (2) adding destroy flag: "destroy = true"
  Bot-us-west-1 = { region = "us-west", tags = ["bots"], destroy = false }
  Bot-us-east-2 = { region = "us-east", tags = ["bots"], destroy = false }
}
