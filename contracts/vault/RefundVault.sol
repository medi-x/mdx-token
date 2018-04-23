pragma solidity ^0.4.18;

import '../math/SafeMath.sol';
import '../ownership/Ownable.sol';

/**
 * @title RefundVault
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the money if crowdsale fails,
 * and forwarding it if crowdsale is successful.
 */
contract RefundVault is Ownable, SafeMath{

  enum State { Active, Refunding, Closed }

  mapping (address => uint256) public deposited;
  mapping (address => uint256) public refunded;
  State public state;

  address[] public reserveWallet;

  event Closed();
  event RefundsEnabled();
  event Refunded(address indexed beneficiary, uint256 weiAmount);

  /**
   * @dev This constructor sets the addresses of
   * 10 reserve wallets.
   * and forwarding it if crowdsale is successful.
   * @param _reserveWallet address[5] The addresses of reserve wallet.
   */
  function RefundVault(address[] _reserveWallet) {
    state = State.Active;
    reserveWallet = _reserveWallet;
  }

  /**
   * @dev This function is called when user buy tokens. Only RefundVault
   * contract stores the Ether user sent which forwarded from crowdsale
   * contract.
   * @param investor address The address who buy the token from crowdsale.
   */
  function deposit(address investor) onlyOwner payable {
    require(state == State.Active);
    deposited[investor] = add(deposited[investor], msg.value);
  }

  event Transferred(address _to, uint _value);

  /**
   * @dev This function is called when crowdsale is successfully finalized.
   */
  function close() onlyOwner {
    require(state == State.Active);
    state = State.Closed;

    uint256 balance = this.balance;

    uint256 reserveAmountForEach = div(balance, reserveWallet.length);

    for(uint8 i = 0; i < reserveWallet.length; i++){
      reserveWallet[i].transfer(reserveAmountForEach);
      Transferred(reserveWallet[i], reserveAmountForEach);
    }

    Closed();
  }

  /**
   * @dev This function is called when crowdsale is unsuccessfully finalized
   * and refund is required.
   */
  function enableRefunds() onlyOwner {
    require(state == State.Active);
    state = State.Refunding;
    RefundsEnabled();
  }

  /**
   * @dev This function allows for user to refund Ether.
   */
  function refund(address investor) returns (bool) {
    require(state == State.Refunding);

    if (refunded[investor] > 0) {
      return false;
    }

    uint256 depositedValue = deposited[investor];
    deposited[investor] = 0;
    refunded[investor] = depositedValue;
    investor.transfer(depositedValue);
    Refunded(investor, depositedValue);

    return true;
  }

}
