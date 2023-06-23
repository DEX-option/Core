pragma solidity ^0.7.0;

interface ERC20Metadata {
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract TokenMetadata {
    function getTokenSymbol(address tokenAddress) external view returns (string memory) {
        ERC20Metadata token = ERC20Metadata(tokenAddress);
        return token.symbol();
    }

    function getTokenName(address tokenAddress) external view returns (string memory) {
        ERC20Metadata token = ERC20Metadata(tokenAddress);
        return token.name();
    }

    function getTokenDecimals(address tokenAddress) external view returns (uint8) {
        ERC20Metadata token = ERC20Metadata(tokenAddress);
        return token.decimals();
    }
}