import schemas.kcl.frps_kcl.frps.frpsschema as Server

Server.ServerConfig {
    version: "v0.62.1"
    auth: Server.AuthServerConfig {
        token: "OVERWRITEME!"
    }
    bindAddr: "0.0.0.0"
    bindPort: 7000
    log: Server.LogConfig {
        level: "info"
        maxDays: 7
    }
    transport: Server.ServerTransportConfig {
        heartbeatTimeout: 60
    }
    detailedErrorsToClient: True
}
