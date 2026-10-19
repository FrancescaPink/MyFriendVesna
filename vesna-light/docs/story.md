# My Friend Vesna: Beyond The Verdict — Story

The story of the game act by act, and how the player's choices change what happens.

## Premise

Bob Parker is an IT technician at **NovaTech Systems**. One night the company's servers are breached:
confidential financial data is stolen and a ransom demand is left behind. The unauthorised login is
traced to the IP address of Bob's house, at the very hours he swears he was asleep.

You are the lawyer from the Baroni & Associati law firm who is assigned the case. The game opens with
the firm's phone call and the prosecution's case file; then you go to see Bob at his house. He has just
moved in, he is scared, and he trusts no one, not even the people who are supposed to help him.

The story runs over three acts: earn Bob's trust, gather evidence in town, face the trial. Every move
from one act to the next is one-way, and the game asks for confirmation before letting you go on.

## Act 1 — The house: Bob's trust

At first Bob is wary. His trust goes up by one point for each of these five actions:

1. **Bringing him breakfast**: a croissant left on the table. Bob notices it, goes to eat it and then
   sits down at his PC.
2. **Helping him with the moving boxes** in the storage room.
3. **Chatting with him** about three topics: the new house, his job, whether he has family or friends
   in town. The topics open up gradually, not all at once.

When his trust reaches five, Bob has something to tell you: he woke up with his laptop already on,
without having touched it, and the only spare keys to the house are with **Finn**, a former colleague
he gave them to so he could water the plants during the move. This is the first piece of evidence in
the case.

**Bob's PC.** There is also a less honest shortcut: going through his computer. If you do it while he
is nearby, he catches you, tells you off and his trust drops. If you distract him instead, by turning on
the radio in the storage room so that he rushes off to switch it off, you can read undisturbed an email
of his to Finn about the spare keys. You get the same evidence, without Bob confiding in you and
without him noticing.

You can leave the house at any time, even without his confession: everyone in town can still be reached.

## Act 2 — The town: the evidence

Five characters live in town. Each of them knows something, but not all of them talk straight away, and
not all of them talk in front of anyone.

| Character | Who they are | What they can give you |
|---|---|---|
| **Mr. Sullivan** | Bob's neighbour | That night he saw an unfamiliar car parked nearby until late, and read part of the plate: *FN-7…* |
| **Alex** | Bob's colleague at NovaTech | Her boss had been ignoring the servers' security alerts for weeks. But she won't say it in front of him |
| **Mr. Jefferson** | NovaTech's director | He wants the case closed fast. Pushed into a corner, he contradicts himself about the security reports |
| **Chloe** | The neighbourhood barista | She knows everyone: she knows Finn is deep in debt, and she links the plate the neighbour saw to his car |
| **Finn** | Bob's former colleague | The real culprit: he kept a copy of the key and used Bob's house to cover his tracks |

### Who is nearby changes what gets said

Alex and Mr. Jefferson stand together outside the NovaTech offices. As long as her boss is there, Alex
refuses to talk. To get her to talk you have to get him out of the way: you can persuade him to go and
have a coffee at the bar. Once he has gone, Alex tells you about the ignored alerts.

### Word gets around

If you have already spoken to Mr. Jefferson and then send him to the bar, he meets Chloe there and tells
her that Bob's lawyer is going around asking questions. When you then go to Chloe you find her on the
phone with Finn, warning him, and you overhear the call. From that moment Finn is on his guard: when you
corner him he has an excuse ready, and you have to push him once more before he gives in. The gossip
helps you (you learn that Chloe and Finn are in touch) but makes the final confrontation harder.

### Finn

Finn paces nervously up and down in the middle of the road; if you tell him to move, he steps onto the
pavement. You can ask him about Bob's key and about the plants: his two answers don't add up with the
dates of the move. When you point it out he breaks down, admits he kept a copy of the key because of his
debts, and hands over the logs he still has on his laptop.

### The six pieces of evidence

1. **The key given to Finn**: Bob's confession, or the email found on his PC (Act 1)
2. **Alex's testimony** about the ignored security alerts: only if Mr. Jefferson isn't there
3. **Mr. Sullivan's testimony** about the suspicious car and the partial plate
4. **Finn's motive**: his debts, as told by Chloe
5. **Mr. Jefferson's contradiction**: you can only press him after hearing Alex, and only if you hold at
   least two pieces of evidence; otherwise he brushes you off with a one-liner
6. **The physical evidence**: the logs from Finn's laptop, once you have unmasked him

You can enter the courthouse whenever you like, even empty-handed: before letting you in, the game
reminds you how many of the six pieces of evidence you have collected. What you bring with you weighs
on the trial.

## Act 3 — The courthouse: the trial as a negotiation

In the courtroom sit the judge, at the raised bench, and the prosecutor, at the prosecution's desk. You
take your place at the defence's desk and open the proceedings.

### The hearing

This is the interactive part, in two steps:

1. **Submitting the evidence.** The evidence you collected can only be used if you submit it to the
   judge.
2. **The examination.** The judge asks you three multiple-choice questions: who had access to the keys
   of Bob's house, how come the intrusion started from his home network, and whether anything is known
   about NovaTech's IT security. You only know the right answers if you really investigated in town.

Evidence and answers count in different ways: the evidence is what the defence can argue with, while
the answers decide how confident the defence is and how far the prosecution is willing to give way.

### The negotiation

From here on the player watches. Prosecution and defence are two agents bargaining over the outcome,
taking turns, with the judge as arbiter: each makes a proposal, the other accepts it or makes a
counter-offer. The defence backs its proposals with the evidence you submitted, one piece at a time,
and every piece moves the prosecution's position. The judge rejects proposals that break the rules,
such as going back on a concession already made. The whole negotiation is shown in a window that can
be scrolled and read again.

If the two sides meet, the case ends in a **plea bargain**. If they don't reach an agreement in the
time allowed, **the judge decides**, based on the weight of the evidence produced in court.

### The endings

The outcome is a sentence on a scale from 0 to 10, translated into five bands: **full acquittal**,
**suspended sentence**, **reduced sentence**, **mitigated conviction**, **full conviction**. At the end
a screen states how it went:

- **Case won**: Bob is acquitted;
- **Partial victory**: suspended or reduced sentence;
- **Case lost**: mitigated or full conviction.

From there you can read the negotiation again, go back to the main menu or quit the game.

## Where it lives in the code

| Part | Files |
|---|---|
| Act 1 | `mind/src/agt/bob.asl`, `env/home/scenes/home.tscn` |
| Act 2 | `mind/src/agt/sullivan.asl`, `alex.asl`, `jefferson.asl`, `chloe.asl`, `finn.asl`, `env/home/scenes/city.tscn` |
| Act 3 | `mind/src/agt/giudice.asl`, `procuratore.asl`, `difesa.asl`, `env/home/scenes/courtroom_interior.tscn` |
| Negotiation protocol | `mind/src/agt/negoziazione/` |
| Dialogue button texts | `env/home/data/topic.json` |
