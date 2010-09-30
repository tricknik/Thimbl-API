from twisted.internet import reactor, defer
from twisted.internet.task import deferLater
from twisted.protocols import basic
from twisted.internet.protocol import Protocol, ClientCreator

class FingerProtocol(basic.LineReceiver):
    def __init__(self, user):
        self.user = user
        self.d = defer.Deferred()
    def connectionMade(self):
        self.transport.write("".join((self.user, "\r\n")))
        self.buf = []
    def dataReceived(self, data):
        self.buf.append(data)
    def connectionLost(self, reason):
        self.gotData(''.join(self.buf))
    def gotData(self, data):
        self.d.callback(data)

def finger(user, host, port=79):
    def connect():
        def output(data):
            s = data.split("Plan:")
            if s:
                plan = s.pop().strip()
                request.setHeader("Access-Control-Allow-Origin", "*")
                request.setHeader("Access-Control-Allow-Methods", "GET")
                if "callback" in request.args:
                    callback = request.args['callback'][0]
                    jsonp = "%s(%s)" % (callback, plan)
                    request.setHeader("Content-Type", "application/javascript")
                    request.write(jsonp)
                else:
                    request.setHeader("Content-Type", "application/json")
                    request.write(plan)
            request.finish()
        def error(fail):
            request.finish()
        def gotProtocol(p):
            p.d.addCallback(output)
            return p.d
        c = ClientCreator(reactor, FingerProtocol, user)
        d = c.connectTCP(host, port)
        d.addCallbacks(gotProtocol, error)
    d = deferLater(reactor, 0, connect)    
    return d

user = None
if "u" in request.args:
    u = request.args["u"]
    s = u[0].split("@")
    if len(s) == 2:
        user = s[0]
        host = s[1]
        reactor.callLater(0, finger, user, host)
if not user:
    request.finish()

