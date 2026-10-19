package vesna.playgrounds.home;

import vesna.SituatedArtifact;
import vesna.WsClient;
import vesna.WsClientMsgHandler;
import java.net.URI;
import org.json.JSONObject;
import cartago.*;

public class Radio extends SituatedArtifact {

    private WsClient client;

    public void init( String region, int limit ) {
        super.init( region, limit );
        try {
            // Si connette sulla porta 8091
            client = new WsClient( new URI( "ws://localhost:8091") );
            client.setMsgHandler( new WsClientMsgHandler() {
                @Override public void handle_msg( String msg ) { }
                @Override public void handle_error( Exception ex ) { }
            });
            client.connect();
        } catch( Exception e ){
            e.printStackTrace();
        }
        defineObsProperty( "status", "playing" );
    }

    @OPERATION
    public void turn_off() throws Exception {
    updateObsProperty( "status", "off" );

    if (client != null && client.isOpen()) { // Controllo di sicurezza
        JSONObject log = new JSONObject();
        log.put( "sender", get_art_name() );
        log.put( "receiver", "artifact" );
        log.put( "type", "interaction" );
        
        JSONObject data = new JSONObject();
        data.put( "type", "turn_off_radio" );
        log.put( "data", data );

        client.send( log.toString() );
        System.out.println("[Radio Artifact] Ordine JSON inviato a Godot sulla porta 8091.");
    } else {
        System.err.println("[Radio Artifact] ERRORE: Client non connesso alla porta 8091!");
    }
}
}