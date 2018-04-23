pragma solidity ^0.4.18;

import './kyc/KYC.sol';
import './MDX.sol';
import './vault/RefundVault.sol';
import './ownership/Ownable.sol';
import './math/SafeMath.sol';
import './lifecycle/Pausable.sol';
import './token/ERC20Basic.sol';

contract MDXCrowdSale is Ownable, SafeMath, Pausable {
    KYC public kyc;
    MDX public token;
    RefundVault public vault;
    address public airDrop;
    address public teamLocker;
    address[] bountyAddresses;
    address[] advisorAddresses;

    struct Period {
        uint256 startTime;
        uint256 endTime;
        uint256 bonus; // used to calculate rate with bonus. ragne 0 ~ 15 (0% ~ 15%)
    }

    uint256 public baseRate; // 1 ETH = 1500 MDX

    Period[] public periods;
    uint8 constant public MAX_PERIOD_COUNT = 8;

    uint256 public tokenRaised;
    uint256 public maxTokenCap;
    uint256 public minTokenCap;

    mapping (address => uint256) public beneficiaryFunded;

    address[] investorList;
    mapping (address => bool) inInvestorList;

    address public MDXController;

    bool public isFinalized;
    uint256 public refundCompleted;

    uint256 public finalizedTime;
    bool public initialized;


    event CrowdSaleTokenPurchase(address indexed _investor, address indexed _beneficiary, uint256 _toFund, uint256 _tokens);
    event StartPeriod(uint256 _startTime, uint256 _endTime, uint256 _bonus);
    event Finalized();
    event PushInvestorList(address _investor);
    event RefundAll(uint256 _numToRefund);
    event ClaimedTokens(address _claimToken, address owner, uint256 balance);
    event Initialize();

    function initialize (
        address _kyc,
        address _token,
        address _vault,
        address _airDrop,
        address _teamLocker,
        address[] _bountyAddresses,
        address[] _advisorAddresses,
        address _tokenController,
        uint256 _maxTokenCap,
        uint256 _minTokenCap,
        uint256 _baseRate
    ) onlyOwner {
        require(!initialized);

        require(_kyc != 0x00 && _token != 0x00 && _vault != 0x00);
        require(_airDrop != 0x00);
        require(_teamLocker != 0x00);
        require(_bountyAddresses[0] != 0x00 && _bountyAddresses.length > 0);
        require(_advisorAddresses[0] != 0x00 && _advisorAddresses.length > 0);
        require(_tokenController != 0x00);
        require(0 < _minTokenCap && _minTokenCap < _maxTokenCap);
        require(_baseRate > 0);

        kyc = KYC(_kyc);
        token = MDX(_token);
        vault = RefundVault(_vault);

        airDrop = _airDrop;
        teamLocker = _teamLocker;
        bountyAddresses = _bountyAddresses;
        advisorAddresses = _advisorAddresses;
        
        MDXController = _tokenController;

        maxTokenCap = _maxTokenCap;
        minTokenCap = _minTokenCap;

        baseRate = _baseRate;

        initialized = true;
        Initialize();
    }

    function () public payable {
        buy(msg.sender);
    }

    function buy(address beneficiary)
    public
    payable
    whenNotPaused
    {
        // check validity
        require(beneficiary != 0x00);
        require(onSale());
        require(validPurchase());
        require(!isFinalized);

        // calculate eth amount
        uint256 weiAmount = msg.value;
        uint256 toFund = weiAmount;
        uint256 reFund = 0;

        uint256 bonus = getPeriodBonus();

        // private sale or registered address
        require((bonus == 50) || kyc.registeredAddress(beneficiary));
        
        uint256 tokens = div(mul(mul(toFund, baseRate), add(100,bonus)), 100);
        uint256 postTokenRaised = add(tokenRaised, tokens);
        if (postTokenRaised > maxTokenCap) {
            tokens = sub(maxTokenCap, tokenRaised);
            toFund = div(mul(tokens,100), mul(baseRate, add(100,bonus)));
            reFund = sub(weiAmount, toFund);
        }

        require(toFund > 0);
        require(toFund <= weiAmount);
        require(reFund >= 0);

        pushInvestorList(msg.sender);

        tokenRaised = add(tokenRaised, tokens);
        beneficiaryFunded[beneficiary] = add(beneficiaryFunded[beneficiary], toFund);

        token.generateTokens(beneficiary, tokens);

        if (reFund > 0) {
            msg.sender.transfer(reFund);
        }

        forwardFunds(toFund);
        CrowdSaleTokenPurchase(msg.sender, beneficiary, toFund, tokens);
    }

    function getBountyCount() public returns(uint256) {
        return bountyAddresses.length;
    }
    
    function getAdvisorCount() public returns(uint256) {
        return advisorAddresses.length;
    }
    
    function pushInvestorList(address investor) internal {
        if (!inInvestorList[investor]) {
            inInvestorList[investor] = true;
            investorList.push(investor);

            PushInvestorList(investor);
        }
    }

    function validPurchase() internal view returns (bool) {
        bool nonZeroPurchase = msg.value != 0;
        return nonZeroPurchase && !maxReached();
    }

    function forwardFunds(uint256 toFund) internal {
        vault.deposit.value(toFund)(msg.sender);
    }

    /**
     * @dev Checks whether minTokenCap is reached
     * @return true if min ether cap is reaced
     */
    function minReached() public view returns (bool) {
        return tokenRaised >= minTokenCap;
    }
    /**
     * @dev Checks whether maxTokenCap is reached
     * @return true if max ether cap is reaced
     */
    function maxReached() public view returns (bool) {
        return tokenRaised == maxTokenCap;
    }

    function getPeriodBonus() public view returns (uint256) {
        bool nowOnSale;
        uint256 currentPeriod;

        for (uint i = 0; i < periods.length; i++) {
            if (periods[i].startTime <= now && now <= periods[i].endTime) {
                nowOnSale = true;
                currentPeriod = i;
                break;
            }
        }

        require(nowOnSale);
        return periods[currentPeriod].bonus;
    }

    // /**
    //  * @dev rate = baseRate * (100 + bonus) / 100
    //  */
    // function calculateRate(uint256 toFund) public view returns (uint256)  {
    //     uint bonus = getPeriodBonus();

    //     // bonus for eth amount
    //     if (additionalBonusAmounts[0] <= toFund) {
    //         bonus = add(bonus, 5); // 5% amount bonus for more than 300 ETH
    //     }

    //     if (additionalBonusAmounts[1] <= toFund) {
    //         bonus = add(bonus, 5); // 10% amount bonus for more than 6000 ETH
    //     }

    //     if (additionalBonusAmounts[2] <= toFund) {
    //         bonus = 25; // final 25% amount bonus for more than 8000 ETH
    //     }

    //     if (additionalBonusAmounts[3] <= toFund) {
    //         bonus = 30; // final 30% amount bonus for more than 10000 ETH
    //     }

    //     return div(mul(baseRate, add(bonus, 100)), 100);
    // }

    function startPeriod(uint256 _startTime, uint256 _endTime) public onlyOwner returns (bool) {
        require(periods.length < MAX_PERIOD_COUNT);
        require(now < _startTime && _startTime < _endTime);

        if (periods.length != 0) {
            require(sub(_endTime, _startTime) <= 7 days);
            require(periods[periods.length - 1].endTime < _startTime);
        }

        // 50% -> 20% -> 10% -> 5% -> 0%...
        Period memory newPeriod;
        newPeriod.startTime = _startTime;
        newPeriod.endTime = _endTime;

        if(periods.length == 0) { // Private Sale
            newPeriod.bonus = 50;
        }
        else if(periods.length == 1) { // Pre Sale
            newPeriod.bonus = 20;
        }
        else if(periods.length == 2) { // 1st Crowd Sale
            newPeriod.bonus = 10;
        }
        else if(periods.length == 3) { // 2nd Crowd Sale
            newPeriod.bonus = 5;
        }
        else {
            newPeriod.bonus = 0;
        }
        
        periods.push(newPeriod);
        StartPeriod(_startTime, _endTime, newPeriod.bonus);
        return true;
    }


    function periodCount() public view returns (uint256) {
        return periods.length;
    }
    
    function onSale() public returns (bool) {
        bool nowOnSale;

        for (uint i = 0; i < periods.length; i++) {
            if (periods[i].startTime <= now && now <= periods[i].endTime) {
                nowOnSale = true;
                break;
            }
        }

        return nowOnSale;
    }
    /**
     * @dev should be called after crowdsale ends, to do
     */
    function finalize() onlyOwner {
        require(!isFinalized);
        require(!onSale() || maxReached());

        finalizedTime = now;

        finalization();
        Finalized();

        isFinalized = true;
    }

    /**
     * @dev end token minting on finalization, mint tokens for dev team and reserve wallets
     */
    function finalization() internal {
        if (minReached()) {
            vault.close();

            uint256 addedAmtForEach = div(maxTokenCap, 6); //125e24; // 12.5억개의 10%

            distributeToken(addedAmtForEach, addedAmtForEach, addedAmtForEach, addedAmtForEach);

            //token.enableTransfers(true);

        } else {
            vault.enableRefunds();
        }
        token.finishGenerating();
        token.changeController(MDXController);
    }

    function distributeToken(uint256 bountyAmount, uint256 advisorAmount, uint256 teamAmount, uint256 airDropAmount) internal {

        require(bountyAddresses[0] != 0x00 && bountyAddresses.length > 0);
        require(advisorAddresses[0] != 0x00 && advisorAddresses.length > 0);
        require(teamLocker != 0x00);
        require(airDrop != 0x00);

        // for bounty
        for(uint256 i=0; i < bountyAddresses.length;i++) {
            if(bountyAddresses[i] != 0x00) {
                token.generateTokens(bountyAddresses[i], div(bountyAmount, bountyAddresses.length));
            }
        }
        
        // for advisor
        for(i=0; i < advisorAddresses.length;i++) {
            if(advisorAddresses[i] != 0x00) {
                token.generateTokens(advisorAddresses[i], div(advisorAmount, advisorAddresses.length));
            }
        }

        // for team members
        token.generateTokens(teamLocker, teamAmount);

        // for air-dorp
        token.generateTokens(airDrop, airDropAmount);
    }

    /**
     * @dev refund a lot of investors at a time checking onlyOwner
     * @param numToRefund uint256 The number of investors to refund
     */
    function refundAll(uint256 numToRefund) onlyOwner {
        require(isFinalized);
        require(!minReached());
        require(numToRefund > 0);

        uint256 limit = refundCompleted + numToRefund;

        if (limit > investorList.length) {
            limit = investorList.length;
        }

        for(uint256 i = refundCompleted; i < limit; i++) {
            vault.refund(investorList[i]);
        }

        refundCompleted = limit;
        RefundAll(numToRefund);
    }

    /**
     * @dev if crowdsale is unsuccessful, investors can claim refunds here
     * @param investor address The account to be refunded
     */
    function claimRefund(address investor) returns (bool) {
        require(isFinalized);
        require(!minReached());

        return vault.refund(investor);
    }

    function claimTokens(address _claimToken) public onlyOwner {

        if (token.controller() == address(this)) {
            token.claimTokens(_claimToken);
        }

        if (_claimToken == 0x0) {
            owner.transfer(this.balance);
            return;
        }

        ERC20Basic claimToken = ERC20Basic(_claimToken);
        uint256 balance = claimToken.balanceOf(this);
        claimToken.transfer(owner, balance);

        ClaimedTokens(_claimToken, owner, balance);
    }
}
