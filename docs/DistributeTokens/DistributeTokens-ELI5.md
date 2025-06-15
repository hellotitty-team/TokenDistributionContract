# Understanding DistributeTokens: Simple Examples

## What is This Contract? The Piggy Bank Example

Imagine you have a special piggy bank. This piggy bank has six different slots on top, and each slot is a different size:

- The first slot (Marketing) is big and takes 30% of all coins
- The second slot (Charity) takes 20% of all coins
- The third slot (Team & Advisors) takes 20% of all coins
- The fourth slot (Community) takes 10% of all coins  
- The fifth slot (Developers) takes 10% of all coins
- The sixth slot (Burn) takes 10% of all coins, but these coins disappear forever

When you put coins into this piggy bank, they automatically slide down into these different slots based on their size. You can't change the size of the slots, and you can't reach inside to move coins from one slot to another.

## How Does It Work? The Chocolate Bar Example

Let's say you have a chocolate bar with 100 squares. The DistributeTokens contract works like this:

1. Someone gives you a chocolate bar (tokens sent to the contract)
2. You break it into pieces following these strict rules:
   - 30 squares go to the Marketing friend
   - 20 squares go to the Charity friend
   - 20 squares go to the Team & Advisors friends
   - 10 squares go to the Community friend
   - 10 squares go to the Developer friend
   - 10 squares get thrown away (burned)

3. You keep a notebook where you write down how many chocolate squares each friend has received in total
4. Anyone can look at your notebook to make sure you're following the rules

## Step-by-Step Example with Tokens

Let's walk through an example with actual numbers:

### Example 1: Distributing 1,000 Tokens

1. Someone sends 1,000 tokens to the DistributeTokens contract
2. Someone (anyone) presses the "distribute" button
3. The contract automatically:
   - Sends 300 tokens (30%) to the Marketing wallet
   - Sends 200 tokens (20%) to the Charity wallet
   - Sends 200 tokens (20%) to the Team & Advisors wallet
   - Sends 100 tokens (10%) to the Community wallet
   - Sends 100 tokens (10%) to the Developer wallet
   - Sends 100 tokens (10%) to the Burn address (these are gone forever)
4. The contract records that it has distributed these tokens
5. Anyone can check the record to confirm the distribution

### Example 2: Distributing Different Token Types

The contract can handle different types of tokens. For example:

1. Someone sends 500 TokenA to the contract
2. The contract distributes TokenA according to the percentages:
   - 150 TokenA to Marketing
   - 100 TokenA to Charity
   - 100 TokenA to Team & Advisors
   - 50 TokenA to Community
   - 50 TokenA to Developers
   - 50 TokenA to Burn

3. Later, someone sends 200 TokenB to the contract
4. The contract distributes TokenB the same way:
   - 60 TokenB to Marketing
   - 40 TokenB to Charity
   - 40 TokenB to Team & Advisors
   - 20 TokenB to Community
   - 20 TokenB to Developers
   - 20 TokenB to Burn

The contract keeps separate records for each type of token, so you can always check how much of TokenA and how much of TokenB has been distributed to each wallet.

## What Makes This Special? The Locked Cookie Jar Example

Imagine a cookie jar with a special lock:

1. Anyone can put cookies in the jar
2. When someone presses the "distribute" button, cookies automatically come out in fixed amounts to specific people
3. Nobody has a key to open the jar in any other way
4. The jar counts and remembers how many cookies each person has received
5. The jar's rules cannot be changed, ever

This is what makes the DistributeTokens contract special - it's completely automatic, can't be tampered with, and provides a transparent record of all distributions.

## Why Is This Important? The Allowance Example

Think about a parent giving allowance money to several children:

1. The parent could hand out the money manually each week, but:
   - The parent might forget
   - The parent might change how much each child gets
   - The children might not trust that they're all being treated fairly

2. With a system like DistributeTokens:
   - The money is distributed automatically
   - The amount each child gets never changes
   - All children can see exactly how much everyone received
   - Nobody (not even the parent) can change the rules

This creates trust because everyone knows exactly what to expect, and the system works the same way every time without anyone controlling it. 