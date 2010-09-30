from twisted.conch.ssh import transport, userauth, connection, channel, \
    common, filetransfer
from twisted.internet import defer, protocol, reactor

class Transport(transport.SSHClientTransport):
    def __init__(self, user, password, callback):
        self.auth = UserAuth(user, Connection(callback))
        self.auth.setPassword(password)
    def verifyHostKey(self, hostKey, fingerprint):
        return defer.succeed(1)
    def connectionSecure(self):
        self.requestService(self.auth)
    def receiveError(self, reasonCode, description):
        request.setResponseCode(401)
        request.finish()

class UserAuth(userauth.SSHUserAuthClient):
    def setPassword(self, password):
        self.password = password
    def getPassword(self):
        return defer.succeed(self.password)
    def getPublicKey(self):
        return

class Connection(connection.SSHConnection):
    def __init__(self, callback):
        connection.SSHConnection.__init__(self)
        self.channel = Channel(2**16, 2**15, self)
        self.channel.setCallback(callback)
    def serviceStarted(self):
        self.openChannel(self.channel)

class Channel(channel.SSHChannel):
    name = 'session'    # must use this exact string
    def setCallback(self, callback):
        self.callback = callback
    def channelOpen(self, data):
        def gotError(fail):
            request.finish()
        def gotResult(result):
            self.sftp = filetransfer.FileTransferClient()
            self.sftp.makeConnection(self)
            self.dataReceived = self.sftp.dataReceived
            self.callback(self.sftp)
        d = self.conn.sendRequest(self, 'subsystem', 
            common.NS('sftp'), wantReply=1)
        d.addCallbacks(gotResult, gotError)
    def closed(self):
        self.loseConnection()

def account(user, password, host, port):
    def gotFile(file):
        thimblLogin = "%s:%s@%s:%s" % (user, password, host, port)
        thimblUser = "%s@%s" % (user, host)
        json = '{ "login":"%s", "user":"%s" }' % (thimblLogin, thimblUser)
        request.setHeader("Access-Control-Allow-Origin", "*")
        request.setHeader("Access-Control-Allow-Methods", "GET")
        request.addCookie("thimbl-login", thimblLogin, path="/account")
        request.addCookie("thimbl-user", thimblUser)
        if "callback" in request.args:
            callback = request.args['callback'][0]
            jsonp = "%s(%s)" % (callback, json)
            request.setHeader("Content-Type", "application/javascript")
            request.write(jsonp)
        else:
            request.setHeader("Content-Type", "application/json")
            request.write(json)
        request.finish()
        if ".plan" in request.args:
            file.writeChunk(0, request.args[".plan"][0])
        file.close()
    def gotProtocol(sftp):
        if ".plan" in request.args:
            mode = filetransfer.FXF_WRITE|filetransfer.FXF_CREAT|filetransfer.FXF_TRUNC
        else:
            mode = filetransfer.FXP_OPEN
        d = sftp.openFile(".plan", mode, {}) 
        d.addCallback(gotFile)
    c = protocol.ClientCreator(reactor, 
            Transport, user, password, gotProtocol).connectTCP(host, port)

host = None
if "u" in request.args:
    u = request.args["u"]
else:
    u = request.getCookie("thimbl-login")

if u:
    s = u[0].split("@")
    if len(s) == 2:
        c = s[0].split(":")
        if len(c) == 2:
            (user, password) = c
            host = s[1]
            port = 22
            if ":" in host:
                (host, port) = host.split(":")
            reactor.callLater(0, account, user, password, host, port)

if not host:
    request.finish()

