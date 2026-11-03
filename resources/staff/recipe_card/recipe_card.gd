extends StaffCard

## Works from any seat. The extra slot uses the Day's combined card mix.
const EXTRA_CHOICES := 1


func extra_card_pick_choices(_ctx: StaffContext) -> int:
	return EXTRA_CHOICES
