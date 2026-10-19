package vesna.via;

import jason.asSemantics.*;
import jason.asSyntax.*;
import org.json.JSONObject;
import vesna.VesnaAgent;

// Questa classe è l'azione interna che permette a Bob di parlare con Godot
public class speak extends DefaultInternalAction {
    @Override
    // Questo metodo viene chiamato quando Bob esegue l'azione .speak
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {
        try {
            // Prende il testo che gli viene scritto in Jason
            String textToSay = ((StringTerm) args[0]).getString();
            // Crea il pacchetto JSON per Godot
            JSONObject data = new JSONObject();
            data.put("text", textToSay);
            JSONObject pacchetto = new JSONObject();
            pacchetto.put("sender", "bob");
            pacchetto.put("receiver", "body");
            pacchetto.put("type", "dialogue");  
            pacchetto.put("data", data);
            // Spedisce tutto usando il collegamento di Vesna
            VesnaAgent agent = (VesnaAgent) ts.getAg();
            agent.perform(pacchetto.toString());
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}