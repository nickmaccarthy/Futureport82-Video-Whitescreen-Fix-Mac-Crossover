import os
import subprocess
import sys

DEFAULT_BOTTLE_LOCATION="$USER/Library/Application\ Support/CrossOver/Bottles"
FP82_BINARY_LOCATION=""

def find_crossover_application(default="/Applications/CrossOver.app") -> str:
    # Check if the CrossOver application exists at the default location
    if os.path.exists(default):
        print(f"CrossOver application found at: {default}")
        return default
    else:
        print(f"CrossOver application not found at: {default}")
        sys.exit(1)
        return None

CROSSOVER_APP = find_crossover_application()

CXWINE = CROSSOVER_APP + "/Contents/SharedSupport/CrossOver/bin/cxbottle"
print(f"CXWINE found at: {CXWINE}")




def remove_bottle(bottle_name: str) -> None:
    # Expand the DEFAULT_BOTTLE_LOCATION with the current user's home directory
    default_bottle_location = os.path.expandvars("$HOME/Library/Application Support/CrossOver/Bottles")
    bottle_path = os.path.join(default_bottle_location, bottle_name)

    # Check if the bottle directory exists
    if os.path.exists(bottle_path):

        try:
            flags = f"--bottle {bottle_name} --delete --force"
            os.system(f"{CXWINE} {flags}")

            print(f"Bottle {bottle_name} removed successfully.")
        except Exception as e:
            os.rmdir(bottle_path)
        # finally:  
        #     print(f"Error removing bottle: {e}")
    else:
        print(f"Bottle {bottle_name} does not exist.")

def create_new_bottle(bottle_name: str) -> str:
    # Expand the DEFAULT_BOTTLE_LOCATION with the current user's home directory
    #default_bottle_location = os.path.expandvars("$HOME/Library/Application Support/CrossOver/Bottles")
    #new_bottle_path = os.path.join(default_bottle_location, bottle_name)

    try:
        flags = f"--bottle {bottle_name} --description 'Bottle for futureport82' --template win10_64 --create --param 'EnvironmentVariables:CX_GRAPHICS_BACKEND=d3dmetal' "
        os.system(f"{CXWINE} {flags}")
    except Exception as e:
        print(f"Error creating new bottle: {e}")
        return None

def list_bottles():
    # Expand the DEFAULT_BOTTLE_LOCATION with the current user's home directory
    default_bottle_location = os.path.expandvars("$HOME/Library/Application Support/CrossOver/Bottles")

    # Check if the directory exists
    if os.path.exists(default_bottle_location):
        print(f"Listing directories in: {default_bottle_location}")

        # List all directories in the DEFAULT_BOTTLE_LOCATION
        bottles = []
        for item in os.listdir(default_bottle_location):
            item_path = os.path.join(default_bottle_location, item)
            if os.path.isdir(item_path):
                bottles.append(item)

        if bottles:
            print("Available bottles:")
            for idx, bottle in enumerate(bottles, start=1):
                print(f"{idx}. {bottle}")

            print(f"{len(bottles) + 1}. Create a new bottle")
            print(f"{len(bottles) + 2}. Remove a bottle")

            # Prompt the user to select a bottle, create a new one, or remove one
            choice = input("Select a bottle by number, create a new one, or remove one: ")

            try:
                choice = int(choice)
                if 1 <= choice <= len(bottles):
                    selected_bottle = bottles[choice - 1]
                    selected_bottle_path = os.path.join(default_bottle_location, selected_bottle)
                    print(f"You selected: {selected_bottle}")
                    return selected_bottle, selected_bottle_path
                elif choice == len(bottles) + 1:
                    new_bottle = input("Enter the name for the new bottle: ")
                    create_new_bottle(new_bottle)
                    new_bottle_path = os.path.join(default_bottle_location, new_bottle)
                    return new_bottle, new_bottle_path
                elif choice == len(bottles) + 2:
                    print("Available bottles to remove:")
                    for idx, bottle in enumerate(bottles, start=1):
                        print(f"{idx}. {bottle}")
                    remove_choice = input("Select a bottle to remove by number: ")
                    try:
                        remove_choice = int(remove_choice)
                        if 1 <= remove_choice <= len(bottles):
                            bottle_to_remove = bottles[remove_choice - 1]
                            bottle_to_remove_path = os.path.join(default_bottle_location, bottle_to_remove)
                            remove_bottle(bottle_to_remove)
                            print(f"Bottle {bottle_to_remove} removed.")
                            return None, None
                        else:
                            print("Invalid choice. Exiting.")
                    except ValueError:
                        print("Invalid input. Please enter a number.")
                else:
                    print("Invalid choice. Exiting.")
            except ValueError:
                print("Invalid input. Please enter a number.")
        else:
            print("No bottles found. You can create a new one.")
            new_bottle = input("Enter the name for the new bottle: ")
            create_new_bottle(new_bottle)
            new_bottle_path = os.path.join(default_bottle_location, new_bottle)
            return new_bottle, new_bottle_path
    else:
        print(f"The directory {default_bottle_location} does not exist.")
        return None, None

if __name__ == "__main__":

    CROSSOVER_APP = find_crossover_application()
    if CROSSOVER_APP:
        print(f"CrossOver application found at: {CROSSOVER_APP}")

    BOTTLE, BOTTLE_DIR = list_bottles()
    if BOTTLE:
        print(f"BOTTLE variable set to: {BOTTLE}")
        print(f"BOTTLE_DIR variable set to: {BOTTLE_DIR}")

        # Prompt for Futureport82 executable location
        FP82_EXE = input("Where is your Futureport82 executable? ").strip("'\"")
        print(f"FP82_EXE variable set to: {FP82_EXE}")

        # Call the mf-fix-cx.sh script with the bottle directory
        try:
            subprocess.run(["./mf-fix-cx.sh", "-e", FP82_EXE, BOTTLE_DIR], check=True)
            print("mf-fix-cx.sh executed successfully.")
        except subprocess.CalledProcessError as e:
            print(f"Error executing mf-fix-cx.sh: {e}")