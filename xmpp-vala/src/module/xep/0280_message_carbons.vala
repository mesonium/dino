using Xmpp.Core;

namespace Xmpp.Xep.MessageCarbons {
    private const string NS_URI = "urn:xmpp:carbons:2";

    public class Module : XmppStreamModule {
        public static ModuleIdentity<Module> IDENTITY = new ModuleIdentity<Module>(NS_URI, "0280_message_carbons_module");

        public void enable(XmppStream stream) {
            Iq.Stanza iq = new Iq.Stanza.set(new StanzaNode.build("enable", NS_URI).add_self_xmlns());
            stream.get_module(Iq.Module.IDENTITY).send_iq(stream, iq);
        }

        public void disable(XmppStream stream) {
            Iq.Stanza iq = new Iq.Stanza.set(new StanzaNode.build("disable", NS_URI).add_self_xmlns());
            stream.get_module(Iq.Module.IDENTITY).send_iq(stream, iq);
        }

        public override void attach(XmppStream stream) {
            stream.stream_negotiated.connect(enable);
            stream.get_module(Message.Module.IDENTITY).received_pipeline.connect(new ReceivedPipelineListener());
            stream.get_module(ServiceDiscovery.Module.IDENTITY).add_feature(stream, NS_URI);
        }

        public override void detach(XmppStream stream) {
            stream.stream_negotiated.disconnect(enable);
        }

        public override string get_ns() { return NS_URI; }
        public override string get_id() { return IDENTITY.id; }
    }

public class ReceivedPipelineListener : StanzaListener<Message.Stanza> {

    private const string[] after_actions_const = {"EXTRACT_MESSAGE_1"};

    public override string action_group { get { return "EXTRACT_MESSAGE_2"; } }
    public override string[] after_actions { get { return after_actions_const; } }

    public override async void run(Core.XmppStream stream, Message.Stanza message) {
        StanzaNode? received_node = message.stanza.get_subnode("received", NS_URI);
        StanzaNode? sent_node = received_node == null ? message.stanza.get_subnode("sent", NS_URI) : null;
        StanzaNode? carbons_node = received_node != null ? received_node : sent_node;
        if (carbons_node != null) {
            StanzaNode? forwarded_node = carbons_node.get_subnode("forwarded", "urn:xmpp:forward:0");
            if (forwarded_node != null) {
                StanzaNode? message_node = forwarded_node.get_subnode("message", Message.NS_URI);
                string? from_attribute = message_node.get_attribute("from", Message.NS_URI);
                // Any forwarded copies received by a Carbons-enabled client MUST be from that user's bare JID; any copies that do not meet this requirement MUST be ignored.
                if (from_attribute != null && from_attribute == get_bare_jid(stream.get_flag(Bind.Flag.IDENTITY).my_jid)) {
                    if (received_node != null) {
                        message.add_flag(new MessageFlag(MessageFlag.TYPE_RECEIVED));
                    } else if (sent_node != null) {
                        message.add_flag(new MessageFlag(MessageFlag.TYPE_SENT));
                    }
                    message.stanza = message_node;
                    message.rerun_parsing = true;
                }
                message.stanza = message_node;
                message.rerun_parsing = true;
            }
        }
    }
}

    public class MessageFlag : Message.MessageFlag {
        public const string ID = "message_carbons";

        public const string TYPE_RECEIVED = "received";
        public const string TYPE_SENT = "sent";
        private string type_;

        public MessageFlag(string type) {
            this.type_ = type;
        }

        public static MessageFlag? get_flag(Message.Stanza message) {
            return (MessageFlag) message.get_flag(NS_URI, ID);
        }

        public override string get_ns() { return NS_URI; }
        public override string get_id() { return ID; }
    }
}
