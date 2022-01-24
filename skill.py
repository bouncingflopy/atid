from penguin_game import *

# sorts the ices by distance from current
def ices_sort(ices, current):
    amounts = [current.get_turns_till_arrival(ice) for ice in ices]
    ices_amounts = {amounts[i]:ices[i] for i in range(len(ices))}
    
    for i in range(len(amounts)):
        small = amounts[i]
        small_place = i
        
        for j in range(len(amounts) - i):
            if amounts[j + i] < small:
                small = amounts[j + i]
                small_place = j + i
        
        temp = amounts[i]
        amounts[i] = amounts[small_place]
        amounts[small_place] = temp
    
    new_ices = [ices_amounts[amount] for amount in amounts]
    
    return new_ices[1:]

def do_turn(game):
    
    ices = game.get_my_icebergs()
    amounts = [ice.penguin_amount for ice in ices] # array of numebr of penguins in each ice
    
    save_amounts = [0 for i in range(len(ices))] # amount of enemy penguins going to each ice
    save_turns = save_amounts # how many turns the enemy penguins are from each ice
    
    # calculate save_amounts and save_turns
    for i in range(len(ices)):
        ice = game.get_my_icebergs()[i]
        
        for group in game.get_enemy_penguin_groups():
            if group.destination == ice:
                save_amounts[i] = group.penguin_amount
                save_turns[i] = group.turns_till_arrival
        
        for group in game.get_my_penguin_groups():
            if group.destination == ice:
                save_amounts[i] -= group.penguin_amount
    
    
    for i in range(len(ices)):
        ice = ices[i]
        needed = ice.penguin_amount + (ice.penguins_per_turn * save_turns[i])
        if save_amounts[i] > needed + 1: # checks if ice needs saving

            ice_sorted = ices_sort(ices, ice) # sorts the ice by distance to the current ice
            
            for j in range(len(ice_sorted)):
                new_ice = ice_sorted[j]
                new_ice_needed = new_ice.penguin_amount + (new_ice.penguins_per_turn * save_turns[j])
                
                if save_amounts[j] < new_ice_needed and save_amounts[i] > needed + 1:
                    save_amounts[i] -= new_ice.penguin_amount
                    new_ice.send_penguins(ice, new_ice.penguin_amount - new_ice_needed - 1)
                    amounts[j] = new_ice_needed + 1
    
    for i in range(len(game.get_my_icebergs())):
        ice = game.get_my_icebergs()[i]
        if save_amounts[i] <= 0 and amounts[i] > 0:
            
            small = game.get_all_icebergs()[0]
            if small == ice:
                small = game.get_all_icebergs()[1]
            for j in game.get_all_icebergs():
                if ice.get_turns_till_arrival(j) < ice.get_turns_till_arrival(small) and j not in game.get_my_icebergs():
                    small = j
            
            if (ice.get_turns_till_arrival(small) * ice.penguins_per_turn < ice.upgrade_cost - ice.penguin_amount) or ice.level == ice.upgrade_level_limit:
                for enemy in game.get_enemy_icebergs():
                    needed = enemy.penguin_amount + (enemy.penguins_per_turn * ice.get_turns_till_arrival(enemy))
                    if amounts[i] > needed + 1:
                        ice.send_penguins(enemy, needed + 1)
                        amounts[i] -= needed + 1
                
                for neutral in game.get_neutral_icebergs():
                    if amounts[i] > neutral.penguin_amount + 1:
                        ice.send_penguins(enemy, neutral.penguin_amount + 1)
                        amounts[i] -= neutral.penguin_amount + 1
            
            if ice.can_upgrade():
                ice.upgrade()
