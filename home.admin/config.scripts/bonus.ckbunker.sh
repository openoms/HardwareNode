    # dependencies
    sudo apt install -y virtualenv python-dev libusb-1.0-0-dev libudev-dev

    # open firewall to LAN (edit to the correct subnet)
    sudo ufw allow from 192.168.3.0/24 to any port 9823 comment "ckbunker"

    # add the udev rules
    cd /etc/udev/rules.d/
    sudo wget https://raw.githubusercontent.com/Coldcard/ckcc-protocol/master/51-coinkite.rules
    sudo udevadm control --reload-rules && sudo udevadm trigger

    # change to bitcoin user - required to access the Tor auth_cookie
    sudo su - bitcoin

    # install ckbunker
    git clone --recursive https://github.com/Coldcard/ckbunker.git
    cd ckbunker
    # reset to the tested release: https://github.com/Coldcard/ckbunker/releases
    git reset --hard v0.9
    virtualenv -p python3 ENV
    source ENV/bin/activate
    pip install -r requirements.txt
    pip install --editable .
    ```

## Setup ckbunker

* Continue after the installation with the `bitcoin` user or run:
    ```
    sudo su - bitcoin
    cd ckbunker
    source ENV/bin/activate
    ```
* start the ckbunker setup at the prompt `(ENV) bitcoin@raspberrypi:~/ckbunker $`:
`$ ckbunker setup`