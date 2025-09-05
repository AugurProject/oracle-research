# Reporting on markets

Since anyone can create markets on PLACEHOLDER, it is important to establish common standards for how markets should be structured and what makes a market invalid. If a market violates these standards, it should be resolved as Invalid. These rules are intentionally written to be somewhat flexible and are not strictly enforced by the protocol itself.

Determining how a market should resolve can be challenging. Market creators should spend significant time crafting well-defined markets that resolve in a way participants would reasonably expect after the real-world event occurs. The wording should aim for the clarity and precision of legal text, leaving no room for loopholes or ambiguity.

Because PLACEHOLDER only supports Yes/No/Invalid outcomes, it is recommended that:

* Yes indicates the event did occur.
* No indicates the event did not occur.
* Invalid is used when the market is flawed or unresolvable.

It is also valuable for REP reporters and traders to discuss market resolutions with one another. Properly resolving markets can be technically difficult and may require domain-specific knowledge, as markets are often interpreted according to established practices within an industry.

## Invalidity rules
A market should be resolved as **Invalid** if any of the following conditions are true:

1. The market question or resolution details are ambiguous, subjective, or undefined.
2. The outcome was not publicly knowable at the time of event expiration.
3. The market could resolve without at least one listed outcome being the winner, unless the resolution details explicitly explain how it should resolve otherwise.
4. The title, resolution details, and outcomes directly contradict each other.
5. The market allows for more than one winning outcome.
6. Any outcome introduces a secondary question instead of directly answering the market question.
7. A resolution source is referenced inconsistently (e.g., URL vs. full name) between the market question and resolution details.
8. A player or team mentioned is not in the correct league, division, or conference at the time the market was created.
9. REP reporters would need to spend excessive time determining how the market should resolve.

## General rules for all markets
A) If no resolution source is defined, markets should resolve using generally available public knowledge.

B) The market question must cover events that occur between the market's start time and end time:
* If no start time is specified, the market creation date and time are used.
* If no end time is specified, the event expiration is used.
* If the event occurs outside of these bounds, the market should resolve as Invalid (unless the market description explicitly states otherwise).

## Examples
TODO: Add example about each rule
- example about market: "what is the pre-image of hash 0x...."
- example of subjective market
- Has X ever won sportsball competition?
- Will X win sportsball competition?
- "Is total amount ETH issued this year more than 1 milj ETH?", might require reporters to run a script against an ethereum node
- "Resolution source: ChatGPT, when provided with this exact question and the pre-prompt ..." -> chatgpt output is personal and openai also can change the underlying model at any time

# TODO
- discuss: during a fork, everyone need to be able to determine the right universe
- discuss: the market description is a JSON with parameters, whats correct struture?
- discuss: traders should dicuss with wider set of people to understand if a market is valid?
- Consider: i might be nitpicking here, but "excessive time" in rule 9 is a bit vague. i would go with something more clear, like "resolution requires analysis beyond what can be reasonably determined from public, authoritative sources"
