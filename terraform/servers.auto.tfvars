servers = {
  # Lobby server
  # private_ip: lobby's nginx fronts prod.triplea-game.org and proxies to the
  # support-server over the same-DC private network.
  lobby = { region = "us-east", tags = ["lobby"], destroy = false, private_ip = true }

  # Support server (Quarkus). Own $5 box, same region as lobby so the lobby
  # nginx -> support proxy hop stays on the private network (sub-ms latency).
  support-server = { region = "us-east", tags = ["support-server"], destroy = false, private_ip = true }

  # Forums
  # Also a placeholder right now with the 'destroy = true', pre-existing server not under TF control
  forums = { region = "us-east", tags = ["lobby"], destroy = true }

  # Marti dice server
  marti = { region = "us-east", tags = ["marti"] }

  # Servers can be deleted in two ways: (1) by removing the server line or (2) adding destroy flag: "destroy = true"
  Bot01-us-west-1    = { region = "us-west", tags = ["bots"], destroy = false, bot_number = 1, bot_location = "California" }
  Bot02-us-east-1    = { region = "us-east", tags = ["bots"], destroy = false, bot_number = 2, bot_location = "Jersey" }
  Bot03-ca-central-1 = { region = "ca-central", tags = ["bots"], destroy = false, bot_number = 3, bot_location = "Toronto" }
  Bot04-gb-lon-1     = { region = "gb-lon", tags = ["bots"], destroy = false, bot_number = 4, bot_location = "London" }
  Bot05-eu-central-1 = { region = "eu-central", tags = ["bots"], destroy = false, bot_number = 5, bot_location = "Frankfurt" }
}
