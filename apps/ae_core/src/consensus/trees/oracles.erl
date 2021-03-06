-module(oracles).
-export([dict_new/7,write/2,get/2,id/1,result/1,
	 question/1,starts/1,root_hash/1, 
	 type/1, 
         %difficulty/1, 
         orders/1, orders_hash/1,
	 set_orders/2, done_timer/1, set_done_timer/2,
	 set_result/2, set_type/2, governance/1,
	 governance_amount/1, creator/1, serialize/1, deserialize/1,
	 verify_proof/4, dict_get/2, dict_write/2, dict_write/3, 
         make_leaf/3, key_to_int/1,
	 test/0]).
-define(name, oracles).
-record(oracle, {id, 
		 result, 
		 question, 
		 starts, 
		 type, %0 means order book is empty, 1 means the order book is holding shares of true, 2 means it holds false, 3 means that it holds shares of "bad question". % 3 1
		 orders = 1,
		 orders_hash,
		 creator,
		 %difficulty = 0,
		 done_timer, % 3 4
		 governance = 0,%if it is non-zero, then this is a governance oracle which can update the value of the variables that define the protocol.
		 governance_amount = 0}).
%we need to store a pointer to the orders tree in the meta data.

governance(X) -> X#oracle.governance.
creator(X) -> X#oracle.creator.
governance_amount(X) -> X#oracle.governance_amount.
id(X) -> X#oracle.id.
result(X) -> X#oracle.result.
question(X) -> X#oracle.question.
starts(X) -> X#oracle.starts.
type(X) -> X#oracle.type.
%difficulty(X) -> X#oracle.difficulty.
orders(X) -> X#oracle.orders.
orders_hash(X) -> X#oracle.orders_hash.
done_timer(X) -> X#oracle.done_timer.
set_orders(X, Orders) ->
    X#oracle{orders = Orders, orders_hash = orders:root_hash(Orders)}.
set_done_timer(X, H) ->
    X#oracle{done_timer = H}.
set_result(X, R) ->
    X#oracle{result = R}.
set_type(X, T) ->
    true = is_integer(T),
    true = T > -1,
    true = T < 5,
    X#oracle{type = T}.
dict_new(ID, Question, Starts, Creator, GovernanceVar, GovAmount, Dict) ->
    true = size(Creator) == constants:pubkey_size(),
    true = (GovernanceVar > -1) and (GovernanceVar < governance:max()),
    Orders = orders:empty_book(),
    MOT = governance:dict_get_value(minimum_oracle_time, Dict),
    #oracle{id = ID,
	    result = 0,
	    question = Question,
	    starts = Starts,
	    type = 3,%1 means we are storing orders of true, 2 is false, 3 is bad.
	    orders = Orders,
            orders_hash = orders:root_hash(Orders),
	    creator = Creator,
	    %difficulty = Difficulty,
	    done_timer = Starts + MOT,
	    governance = GovernanceVar,
	    governance_amount = GovAmount
	   }.
root_hash(Root) ->
    trie:root_hash(?name, Root).
serialize(X) ->
    KL = constants:key_length(),
    HS = constants:hash_size(),
    PS = constants:pubkey_size(),
    Question = X#oracle.question,
    %Orders = orders:root_hash(X#oracle.orders),
    %Orders = X#oracle.orders_hash,
    Orders = case X#oracle.orders of
                 0 -> X#oracle.orders_hash;
                     %Account#acc.bets_hash;
                 Z -> orders:root_hash(Z)
             end,
    HS = size(Question),
    HS = size(Orders),
    HB = constants:height_bits(),
    %DB = constants:difficulty_bits(),
    true = size(X#oracle.creator) == PS,
    true = size(Question) == HS,
    true = size(Orders) == HS,
    <<(X#oracle.id):(HS*8),
      (X#oracle.result):8,
      (X#oracle.type):8,
      (X#oracle.starts):HB,
      %(X#oracle.difficulty):DB,
      (X#oracle.done_timer):HB,
      (X#oracle.governance):8,
      (X#oracle.governance_amount):8,
      (X#oracle.creator)/binary,
      Question/binary,
      Orders/binary>>.
deserialize(X) ->
    KL = constants:key_length(),
    PS = constants:pubkey_size()*8,
    HS = constants:hash_size()*8,
    HEI = constants:height_bits(),
    %DB = constants:difficulty_bits(),
    <<ID:HS,
     Result:8,
     Type:8,
     Starts:HEI,
     %Diff:DB,
     DT:HEI,
     Gov:8,
     GovAmount:8,
     Creator:PS,
     Question:HS,
     Orders:HS
     >> = X,
    #oracle{
           id = ID,
           type = Type,
           result = Result,
           starts = Starts,
           question = <<Question:HS>>,
           creator = <<Creator:PS>>,
           %difficulty = Diff,
           done_timer = DT,
           governance = Gov,
           governance_amount = GovAmount,
           orders_hash = <<Orders:HS>>
      }.
dict_write(Oracle, Dict) ->
    dict_write(Oracle, 0, Dict).
dict_write(Oracle, Meta, Dict) ->
    Key = Oracle#oracle.id,
    dict:store({oracles, Key},
               {serialize(Oracle), Meta},
               Dict).
write(Oracle, Root) ->
    %meta is a pointer to the orders tree.
    V = serialize(Oracle),
    Key = Oracle#oracle.id,
    Meta = Oracle#oracle.orders,
    trie:put(Key, V, Meta, Root, ?name).
dict_get(ID, Dict) ->
    X = dict:fetch({oracles, ID}, Dict),
    case X of
        0 -> empty;
        {0, _} -> empty;
        {Y, Meta} ->
            Y2 = deserialize(Y),
            Y2#oracle{orders = Meta}
        %_ -> deserialize(X)
    end.
key_to_int(X) -> X.
get(ID, Root) ->
    true = is_integer(ID),
    {RH, Leaf, Proof} = trie:get(ID, Root, ?name),
    V = case Leaf of 
	    empty -> empty;
	    L -> 
		X = deserialize(leaf:value(L)),
		M = leaf:meta(L),
		X#oracle{orders = M}
	end,
    {RH, V, Proof}.
make_leaf(Key, V, CFG) ->
    leaf:new(Key, V, 0, CFG).
verify_proof(RootHash, Key, Value, Proof) ->
    trees:verify_proof(?MODULE, RootHash, Key, Value, Proof).
    

test() ->
    %headers:dump(),
    %block:initialize_chain(),
    %tx_pool:dump(),
    %{Trees, _, _} = tx_pool:data(),
    %Root0 = constants:root0(),
    %X0 = new(1, testnet_hasher:doit(1), 2, constants:master_pub(), constants:initial_difficulty(), 0, 0, Trees),
    %X = set_result(X0, 3),
    %X2 = deserialize(serialize(X)),
    %X3 = X2#oracle{orders = X#oracle.orders},
    %lager:info("~s", [packer:pack({oracles_test, X, X3})]),
    %X = X3,
    %NewLoc = write(X, Root0),
    %{Root1, X, Path1} = get(X#oracle.id, NewLoc),
    %{Root2, empty, Path2} = get(X#oracle.id, Root0),
    %true = verify_proof(Root1, X#oracle.id, serialize(X), Path1),
    %true = verify_proof(Root2, X#oracle.id, 0, Path2),
    test2().
test2() ->
    %{Trees, _, _} = tx_pool:data(),
    %OID = 2,
    %Root0 = constants:root0(),
    %X0 = new(OID, testnet_hasher:doit(1), 2, constants:master_pub(), constants:initial_difficulty(), 0, 0, Trees),
    %io:fwrite("test oracle "),
    %io:fwrite(packer:pack(X0)),
    %io:fwrite("\n"),
    %Dict0 = dict:new(),
    %Dict1 = dict_write(X0, orders(X0), Dict0),
    %io:fwrite(packer:pack(dict:fetch_keys(Dict1))),
    %io:fwrite("\n"),
    %X0 = dict_get(OID, Dict1),
    success.
    
