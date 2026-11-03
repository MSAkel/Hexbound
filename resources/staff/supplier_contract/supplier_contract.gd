extends StaffCard

## Works from any seat.
const PRICE_DISCOUNT := 1
const CARD_CHANGE := -1


func pack_price_discount(_ctx: StaffContext) -> int:
	return PRICE_DISCOUNT


func pack_card_count_change(_ctx: StaffContext) -> int:
	return CARD_CHANGE
