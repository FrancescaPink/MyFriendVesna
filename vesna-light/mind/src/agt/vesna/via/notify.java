package vesna.via;

import jason.asSemantics.*;
import jason.asSyntax.*;
import org.json.JSONObject;
import vesna.VesnaAgent;

// Azione interna per una notifica UI temporanea (es. "+1 Fiducia"), separata
// dal dialogo di Bob: stesso schema di speak.java ma con type "notify",
// cosi' non interferisce in alcun modo col riquadro di dialogo esistente.
public class notify extends DefaultInternalAction {
    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {
        try {
            String testoDaMostrare = ((StringTerm) args[0]).getString();
            JSONObject data = new JSONObject();
            data.put("text", testoDaMostrare);
            JSONObject pacchetto = new JSONObject();
            pacchetto.put("sender", "bob");
            pacchetto.put("receiver", "body");
            pacchetto.put("type", "notify");
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
