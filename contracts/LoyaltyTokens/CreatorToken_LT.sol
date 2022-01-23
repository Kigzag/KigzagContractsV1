// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ICreatorToken_LT.sol";
import "./interfaces/ICreatorDAO_LT.sol";
import "./interfaces/IXeldoradoCreatorFactory_LT.sol";
import "../libraries/SafeMath.sol";

contract CreatorToken_LT is ERC20, ICreatorToken_LT {
    using SafeMath  for uint;

    address private creatorfactory;
    uint private unlocked;
    address public override creator;
    address public override dao;

    modifier lock() {
        require(unlocked == 1, 'Xeldorado: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyHolders() {
        require(ICreatorToken_LT(address(this)).balanceOf(msg.sender) > 0 , 'Xeldorado: not a token owner');
        _;
    }

    constructor(address _creator, string memory name, string memory symbol) ERC20(name,symbol){
        creatorfactory = msg.sender; // creator factory
        creator = _creator;
        unlocked = 1;
    }

    function initialize(address _dao) public virtual override {
        require(msg.sender==creatorfactory,'Xeldorado: only creator factory allowed');
        require(dao==address(0),'Xeldorado: DAO already added');
        dao = _dao;
    }

    // msg.sender's tokens will be burnt
    function burnMyTokens(uint _amount) public virtual override lock {
        _burn(msg.sender,_amount);
        emit tokensBurnt(address(this), _amount, msg.sender);
    }
    
    function mintTokens(address _to, uint _amount) public virtual override {
        require(msg.sender==dao,'Xeldorado: only dao can mint tokens');
        _mint(_to,_amount);
        emit tokensMinted(address(this), _amount, _to);
    }
      
    function calculateFee(uint amount, uint fee) internal pure returns (uint) {
        // fee percent in scale of 10000
        return amount.mul(fee)/10000;
    }

    // msg.sender is _to
    // amount in quantity of creator tokens 
    // NOT in 10^18 decimal
    function buyTokens(uint _amount, address _basetoken) public virtual override {
        uint discount;
        uint total;
        if(IXeldoradoCreatorFactory_LT(creatorfactory).noOFTokensForDiscount() <= IERC20(IXeldoradoCreatorFactory_LT(creatorfactory).exchangeToken()).balanceOf(msg.sender)) {
            discount = IXeldoradoCreatorFactory_LT(creatorfactory).discount();
        }

        if(_basetoken == IXeldoradoCreatorFactory_LT(creatorfactory).networkWrappedToken()){
            total = _amount.mul(IXeldoradoCreatorFactory_LT(creatorfactory).getCreatorSaleFee(creator)[0]);
        }

        else if(_basetoken == IXeldoradoCreatorFactory_LT(creatorfactory).usdc() || _basetoken == IXeldoradoCreatorFactory_LT(creatorfactory).dai()){
            total = _amount.mul(IXeldoradoCreatorFactory_LT(creatorfactory).getCreatorSaleFee(creator)[1]);
        }

        else{
            require(0==1, 'Xeldorado: invlaid basetoken');
        }

        uint totalFee = calculateFee(total, IXeldoradoCreatorFactory_LT(creatorfactory).fee().sub(discount));
        require(IERC20(_basetoken).transferFrom(msg.sender, dao, total.sub(totalFee)),'Xeldorado: base token transfer failed');
        require(IERC20(_basetoken).transferFrom(msg.sender, IXeldoradoCreatorFactory_LT(creatorfactory).feeTo(), totalFee),'Xeldorado: base token transfer failed');
        _mint(msg.sender, _amount.mul(10**18));
        ICreatorDAO_LT(dao).currentBalanceUpdate();
    }
}