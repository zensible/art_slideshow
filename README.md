
# Art Slideshow

## About

This app displays a randomized slideshow of high quality artworks from the Metropolitan Museum's [public domain collection](http://www.metmuseum.org/about-the-met/policies-and-documents/image-resources).

The included database has 201,000 artworks, separated by department and era.

## Installation

This app requires you to run a Rails server.

### 1. Check out the code

git clone ---

### 2. Install mysql

Mac: brew install mysql
Ubuntu: sudo apt-get install mysql-server

### 3. Configure app

cp config/database.yml.example config/database.yml

Edit config/database.yml and set your mysql host/username/password

### 4. Install gems

bundle install

If you get a 'wrong ruby version' error, install rvm:

https://rvm.io/rvm/install

...and ruby 2.3.3:

rvm install 2.3.3

### 5. Create/populate database

#### 5.1: create db

rake db:create
rake db:migrate

#### 5.2: Import artwork database

Unzip lib/tasks/MetObjects.csv.zip

rake csv:import

### 6. Start server

rails s -b 0.0.0.0 -p 80

This tells the server to serve to all IP addresses on port 80.

You should see a message like this:

Success! You may access the slideshow at this address on the local network:

http://192.168.0.103:5050


### 7. Optional: make server available over the internet

#### 7.1: get a free DNS name

Author recommends:

https://www.duckdns.org/

#### 7.2: Configure your router to direct traffic to the IP address / port you set in step 6:

http://www.wikihow.com/Set-Up-Port-Forwarding-on-a-Router

You should then be able to access your art slideshow from any internet-connected device

# Other stuff:

If you're trying to create a digital picture frame from an Android device, the author recommends this combo of apps:

https://play.google.com/store/apps/details?id=tk.klurige.fullscreenbrowser&hl=en

https://play.google.com/store/apps/details?id=com.synetics.stay.alive&hl=en

If you're just viewing it in a browser, the author recommends Chrome and using View -> Full Screen Mode and View -> uncheck 'Always Show Toolbar in Full Screen Mode'