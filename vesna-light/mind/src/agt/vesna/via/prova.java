package vesna.via;

import jason.asSemantics.*;
import jason.asSyntax.*;
import org.json.JSONObject;
import vesna.VesnaAgent;

// Azione interna per sbloccare una prova nell'inventario (Atto 1/2, vedi
// docs/story.md "Prove raccolte"). Stessa struttura di speak.java/notify.java
// ma type "prova_raccolta": nodo/gestione completamente separati, non tocca
// il dialogo ne' le notifiche di fiducia.
public class prova extends DefaultInternalAction {
    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {
        try {
            String idProva = ((StringTerm) args[0]).getString();
            JSONObject data = new JSONObject();
            data.put("id", idProva);
            JSONObject pacchetto = new JSONObject();
            pacchetto.put("sender", ts.getAgArch().getAgName());
            pacchetto.put("receiver", "body");
            pacchetto.put("type", "prova_raccolta");
            pacchetto.put("data", data);
            VesnaAgent agent = (VesnaAgent) ts.getAg();
            agent.perform(pacchetto.toString());
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}
