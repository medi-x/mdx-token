const fs = require("fs");
const path = require("path");
const moment = require("moment");

const MDX = artifacts.require("MDX.sol");
const RefundVault = artifacts.require("vault/RefundVault.sol");
const MiniMeTokenFactory = artifacts.require("token/MiniMeTokenFactory.sol");
const MDXCrowdSale = artifacts.require("MDXCrowdSale.sol");
const KYC = artifacts.require("kyc/KYC.sol");
const TeamLocker = artifacts.require("TeamLocker.sol");
const AirDrop = artifacts.require("AirDrop.sol");

module.exports = async function (deployer, network, accounts) {

//    console.log("[accounts]");
//    accounts.forEach((account, i) => console.log(`[${ i }]  ${ account }`));
    try {
        let maxTokenCap, minTokenCap;

        let tokenFactory, token, vault, presale;
        let kyc, crowdsale;

        let vaultOwners;
        let teamLocker;
        let airDrop;
        let MDXController;


        let baseRate;

        let presale_address;
        let token_address;
        let vault_address;

        let firstPeriodStartTime, firstPeriodEndTime;
        let periodStartTime1, periodEndTime1;
        let periodStartTime2, periodEndTime2;
        let periodStartTime3, periodEndTime3;
        let periodStartTime4, periodEndTime4;
        let periodStartTime5, periodEndTime5;
        let periodStartTime6, periodEndTime6;
        let periodStartTime7, periodEndTime7;


        //TODO: check
        // firstPeriodStartTime = moment.utc("2017-12-11T03:00").unix();
        // firstPeriodEndTime = moment.utc("2017-12-17T15:00").unix();
//        console.log('firstPeriodStartTime', firstPeriodStartTime);
//        console.log('firstPeriodEndTime', firstPeriodStartTime);
        

        periodStartTime1 = moment.utc("2017-12-18T03:00").unix();
        periodEndTime1 = moment.utc("2017-12-24T15:00").unix();

        periodStartTime2 = moment.utc("2017-12-25T03:00").unix();
        periodEndTime2 = moment.utc("2017-12-31T15:00").unix();

        periodStartTime3 = moment.utc("2018-01-01T03:00").unix();
        periodEndTime3 = moment.utc("2018-01-07T15:00").unix();

        periodStartTime4 = moment.utc("2018-01-08T03:00").unix();
        periodEndTime4 = moment.utc("2018-01-14T15:00").unix();

        periodStartTime5 = moment.utc("2018-01-15T03:00").unix();
        periodEndTime5 = moment.utc("2018-01-21T15:00").unix();

        periodStartTime6 = moment.utc("2018-01-22T03:00").unix();
        periodEndTime6 = moment.utc("2018-01-28T15:00").unix();

        periodStartTime7 = moment.utc("2018-01-29T03:00").unix();
        periodEndTime7 = moment.utc("2018-02-04T15:00").unix();

        //TODO: check
        maxTokenCap = 75e25; //7.5억 tokens
        minTokenCap = 10e25; // 1억 tokens

        //TODO: check
        baseRate = 2500;

        //TODO: check
        vaultOwners = [
            "0x1111111111111111111111111111111111111111",
            "0x2222222222222222222222222222222222222222",
            "0x3333333333333333333333333333333333333333",
            "0x4444444444444444444444444444444444444444"
        ];

        //TODO: check
        MDXController = "0x05bbcf30914239a5dde9e5efded6671518f30196";
//        MDXController = "0x01ad78dbd65579882a7058bc19b104103627a2ff";

        tokenFactory = await MiniMeTokenFactory.new();
        console.log("tokenFactory deployed at", tokenFactory.address);
        
        token = await MDX.new(tokenFactory.address);
        console.log("token deployed at", token.address);
        
        vault = await RefundVault.new(vaultOwners);
        console.log("vault deployed at", vault.address);
        
        
        
        
        kyc = await KYC.new();
        console.log("kyc deployed at", kyc.address);

        // crowdsale
        crowdsale = await MDXCrowdSale.new();
        console.log("crowdsale deployed at", crowdsale.address);
        
        teamLocker = await TeamLocker.new(
            token.address,
            crowdsale.address,
            vaultOwners // team member addresses
        );
        console.log("teamLocker deployed at", teamLocker.address);

        // for air-drop
        airDrop = await AirDrop.new(token.address);
        console.log("airDrop deployed at", airDrop.address);

        await token.changeController(crowdsale.address);
        await vault.transferOwnership(crowdsale.address);
        
        await crowdsale.initialize(
            kyc.address,
            token.address,
            vault.address,
            airDrop.address,
            teamLocker.address,
            vaultOwners, // bounty
            vaultOwners, // advisor
            MDXController,
            maxTokenCap,
            minTokenCap,
            baseRate
        );
        
        console.log("crowdsale initialized");

        // await crowdsale.startPeriod(firstPeriodStartTime, firstPeriodEndTime);
        // await crowdsale.startPeriod(periodStartTime1, periodEndTime1);
        // await crowdsale.startPeriod(periodStartTime2, periodEndTime2);
        // await crowdsale.startPeriod(periodStartTime3, periodEndTime3);
        // await crowdsale.startPeriod(periodStartTime4, periodEndTime4);
        // await crowdsale.startPeriod(periodStartTime5, periodEndTime5);
        // await crowdsale.startPeriod(periodStartTime6, periodEndTime6);
        // await crowdsale.startPeriod(periodStartTime7, periodEndTime7);

        // TODO: check
        let ts = moment();
        let periods = [
            ts.add(1,'s').unix(), ts.add(3600,'s').unix(),
            ts.add(1,'s').unix(), ts.add(3600,'s').unix(),
            ts.add(1,'s').unix(), ts.add(3600,'s').unix(),
            ts.add(1,'s').unix(), ts.add(3600,'s').unix(),
            ts.add(1,'s').unix(), ts.add(3600,'s').unix(),
            ts.add(1,'s').unix(), ts.add(3600,'s').unix()
        ];
        
        for(i=0; i<periods.length; i++) {
            _start = periods[i++];
            _end = periods[i];

            console.log(_start, _end);
            
            await crowdsale.startPeriod(_start, _end);

            console.log('period', _start, _end);
        }
        
        console.log("crowdsale periods started");

        fs.writeFileSync(path.join(__dirname, "../contracts.json"), JSON.stringify({
            token: token.address,
            vault: vault.address,
            kyc:kyc.address,
            crowdsale: crowdsale.address,
            teamLocker: teamLocker.address,
            airDrop: airDrop.address,
            vaultOwners:vaultOwners
        }, undefined, 2));
    } catch (e) {
        console.error(e);
    }
};
