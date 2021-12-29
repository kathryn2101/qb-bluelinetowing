# qb-bluelinetowing
This is a script i worked on for one of my companies in my city its based of the police script with in corps from the towing script.


Blue Line Towing has hit QBCore.
Was mostly frames for qb-policejob and qb-ambulancejob with snipets from qb-towjob.

All I ask is if you use to provide credit where it is due.




Add to qb-core/shared.lua/QBShared.Jobs

	['bltowing'] = {
        	label = 'Blue Line Towing',
        	defaultDuty = true,
        	grades = {
            		['0'] = {
                	    name = 'Recruit',
                            payment = 500
            		},
            		['1'] = {
                	    name = 'Driver',
                	    payment = 800
            		},
	    		['2'] = {
	        	    name = 'Mechanic',
		 	    payment = 800
	    		},
            		['3'] = {
                	    name = 'Manager',
                	    payment = 1000
            		},
            		['4'] = {
                	    name = 'Co-Owner',
                	    isboss = true,
                	    payment = 1200
            		},
            		['5'] = {
                	    name = 'Owner',
                	    isboss = true,
                	    payment = 1200
            		},
        	},
    	},
    
    
we got our tow vehicles from Bagged Customs, cfx forums and our script came from theebu
links provided below
    
    https://forum.cfx.re/t/2018-f150-extended-cab-work-truck/4779839
    https://www.patreon.com/posts/baggedcustoms-on-42033905
    https://www.patreon.com/posts/ct660-tow-truck-28435285
    
    this truck comes with its own tow script but no winch
    https://forum.cfx.re/t/release-flatbed-w-working-bed/192047
    
    flatbed script with winch for the 2 baggedcustom flatbeds
    https://www.youtube.com/watch?v=3UZ_31Pyq-k
    
    
