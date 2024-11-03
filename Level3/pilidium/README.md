# Chess - Variant "Fidelity"

All the rules of Chess apply to this variant with the exception of an additional rule, the rule of "Fidelity".

## The Rule of "Fidelity"

- *A piece of one kind cannot capture a piece of the same kind.*

- In other words, the following moves are invalidated:

	- Pawn captures Pawn (essentially invalidating en passant)
	- Knight captures Knight
	- Bishop captures Bishop
	- Rook captures Rook
	- Queen captures Queen

That's it.

## Inner workings

- For a selected piece, if there exists a move by which another piece gets captured, then it is checked whether the capturable piece is of the same kind as that of the selected piece.

- In the event it is true, the move is invalidated. Otherwise, it is considered to be a valid move.

