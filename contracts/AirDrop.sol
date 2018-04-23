pragma solidity ^0.4.18;

import './ownership/Ownable.sol';
import "./token/ERC20Basic.sol";
import "./token/SafeERC20.sol";
import "./math/SafeMath.sol";

contract AirDrop is Ownable, SafeMath {
    using SafeERC20 for ERC20Basic;

    ERC20Basic public token;
    mapping (address => uint256) public beneficiaries;
    uint256 dropedTokens;

    function AirDrop(address _token) {
        require(_token != 0x00);
        token = ERC20Basic(_token);
    }

    function doAirDrop(address[] _tos, uint256[] _tokenAmts) public onlyOwner returns (bool success) {
        require(_tos.length > 0 && _tos.length == _tokenAmts.length);

        uint256 reqedTokens;
        for(uint i=0; i<_tos.length; i++) {
            require(_tos[i] != 0x00 && _tokenAmts[i] > 0);
//            require(beneficiaries[_tos[i]] == 0);
            reqedTokens += _tokenAmts[i];
        }

        uint256 bal = token.balanceOf(address(this));
        require(bal >= reqedTokens);

        for(i=0; i<_tos.length; i++) {
            token.safeTransfer(_tos[i], _tokenAmts[i]);
            beneficiaries[_tos[i]] = _tokenAmts[i];
        }
        return true;
    }
}
