servers = {
  # Lobby server
  # Mostly a placeholder right now with the 'destroy = true'
  # The lobby server is a pre-existing server, we will be upgrading it in place
  lobby = { region = "us-east", tags = ["lobby"], destroy = true }

  # Forums
  # Also a placeholder right now with the 'destroy = true', pre-existing server not under TF control
  forums = { region = "us-east", tags = ["lobby"], destroy = true }

  # Marti dice server
  marti = { region = "us-east", tags = ["marti"] }

  # Servers can be deleted in two ways: (1) by removing the server line or (2) adding destroy flag: "destroy = true"
  Bot01-California = { region = "us-west", tags = ["bots"], destroy = false }
  Bot02-Jersey = { region = "us-east", tags = ["bots"], destroy = false }
  Bot03-Toronto = { region = "ca-central", tags = ["bots"], destroy = false }
  Bot04-London = { region = "gb-lon", tags = ["bots"], destroy = false }
  Bot05-Frankfurt = { region = "eu-central", tags = ["bots"], destroy = false }
}
