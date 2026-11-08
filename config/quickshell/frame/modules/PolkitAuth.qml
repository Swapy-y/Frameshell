import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  PolkitAuth.qml - the shell is the polkit agent: when an app needs admin
//  rights, the request comes here and AuthDialog.qml asks for the password.
//
//  Only one agent can work per session, so hyprpolkitagent is stopped first.
//  If the shell's agent cannot register (Quickshell built without polkit, or
//  another agent holds the session), hyprpolkitagent is started again, so
//  there is always a password dialog. shell.qml loads this file through a
//  Loader, so a Quickshell without the polkit module still runs the shell.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property var agent: null
    property int tries: 0

    Component {
        id: agentComponent
        PolkitAgent {}
    }

    function startAgent() {
        if (agent)
            agent.destroy();
        agent = agentComponent.createObject(root);
        check.restart();
    }

    // 1. make room: stop hyprpolkitagent if it runs (it would hold the session)
    Process {
        running: true
        command: ["sh", "-c", "systemctl --user stop hyprpolkitagent.service >/dev/null 2>&1; pkill -x hyprpolkitagent >/dev/null 2>&1; sleep 0.3; true"]
        onExited: root.startAgent()
    }

    // 2. registered? On a shell reload the old agent may still hold the session
    //    for a moment, so try a few times before falling back to hyprpolkitagent.
    Timer {
        id: check
        interval: 1500
        onTriggered: {
            if (root.agent && root.agent.isRegistered)
                return;
            if (root.tries < 3) {
                root.tries++;
                root.startAgent();
            } else {
                console.warn("PolkitAuth: could not register the polkit agent, starting hyprpolkitagent instead");
                Quickshell.execDetached(["sh", "-c", "systemctl --user start hyprpolkitagent.service 2>/dev/null || exec /usr/lib/hyprpolkitagent/hyprpolkitagent"]);
            }
        }
    }

    AuthDialog {
        flow: root.agent && root.agent.isActive ? root.agent.flow : null
    }
}
