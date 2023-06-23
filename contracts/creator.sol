pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

abstract contract ERC20Interface {
    function totalSupply() public virtual view returns (uint);
    function balanceOf(address tokenOwner) public virtual  view returns (uint balance);
    function allowance(address tokenOwner, address spender) public virtual  view returns (uint remaining);
    function transfer(address to, uint tokens) public virtual  returns (bool success);
    function approve(address spender, uint tokens) public virtual  returns (bool success);
    function transferFrom(address from, address to, uint tokens) public virtual  returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// ----------------------------------------------------------------------------
// Safe Math Library
// ----------------------------------------------------------------------------
contract SafeMath {
    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a); c = a - b; } function safeMul(uint a, uint b) public pure returns (uint c) { c = a * b; require(a == 0 || c / a == b); } function safeDiv(uint a, uint b) public pure returns (uint c) { require(b > 0);
        c = a / b;
    }
}

contract PIEXCreator is ERC721URIStorage, SafeMath, Ownable {
    using Counters for Counters.Counter;
    address public RevenueReceiver;

    uint256 private hash = 0;

    struct OptionParams {
        address creator;
        address[2] path;
        uint256[2] ratio;
        uint[2] balances;
        uint256 creation;
        uint256 expiration;
    }

    Counters.Counter public _tokenIdCounter;
    mapping(uint256 => OptionParams) private _params;

    constructor(
       address _recevier
    ) ERC721(
        "PIEXPersonalOptions", "OPTIONS"
        ) {
            RevenueReceiver = _recevier;
        }


    function GetTotalOptionCount () public view returns (uint) {
        return _tokenIdCounter.current();
    }


    function safeMint(address to, 
                      address[2] memory _path,
                      uint256[2] memory _ratio,
                      uint32 expiration
                      ) public {
        require(expiration > block.timestamp, "Expiration date must be larger than now");
        require(_ratio[0] > 10000 && _ratio[1] > 10000, "Values can not be smaller than 10000 wei");
        uint256 tokenId = _tokenIdCounter.current();
        TransferHelper.safeTransferFrom(_path[0], msg.sender, address(this), _ratio[0]);
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        uint[2] memory _balances = [_ratio[0], 0];
        _params[tokenId] = OptionParams(
            msg.sender,
            _path,
            _ratio,
            _balances,
            block.timestamp,
            expiration
        );
    }

    function GetOptionData (uint _tokenId) external view returns (OptionParams memory) {
        return _params[_tokenId];
    }

    function IsOptionExecuted (uint _tokenId) external view returns (bool) {
        if (_params[_tokenId].balances[0] == 0) {
            return true;
        } else {
            return false;
        }
    }

    function ExecuteOption (uint _tokenId) external {
        require(this.ownerOf(_tokenId) == msg.sender, "You need to be an option owner to execute");
        require(_params[_tokenId].expiration > block.timestamp, "Option is already expired");
        require(!this.IsOptionExecuted(_tokenId), "Option is already executed");
        TransferHelper.safeTransferFrom(_params[_tokenId].path[1], 
        msg.sender, address(this), _params[_tokenId].ratio[1]);
        TransferHelper.safeTransfer(_params[_tokenId].path[0], 
        msg.sender, _params[_tokenId].ratio[0]);
        _params[_tokenId].balances = [0, _params[_tokenId].ratio[1]];
    }

    function WithdrawBasicAssets (uint _tokenId, address to) external {
        require(_params[_tokenId].creator == msg.sender, "Caller is not the option creator");
        require(block.timestamp > _params[_tokenId].expiration, "Option is still not expired");
        if (_params[_tokenId].ratio[0] > 0) {
            TransferHelper.safeTransfer(_params[_tokenId].path[0], 
            to, _params[_tokenId].ratio[0]);
        }
        if (_params[_tokenId].ratio[1] > 0) {
            TransferHelper.safeTransfer(_params[_tokenId].path[1], 
            to, _params[_tokenId].ratio[1]);
        }
        _params[_tokenId].balances = [0, 0];
    }

}
