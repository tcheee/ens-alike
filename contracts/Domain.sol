// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {StringUtils} from "./libraries/StringUtils.sol";
import {Base64} from "./libraries/Base64.sol";

import "hardhat/console.sol";

contract Domains is ERC721URIStorage {
  error Unauthorized();
  error AlreadyRegistered();
  error InvalidName(string name);

  address payable public owner;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  string public tld;
  string svgPartOne = '<svg xmlns="http://www.w3.org/2000/svg" width="270" height="270" fill="none"><path fill="url(#a)" d="M0 0h270v270H0z"/><defs><filter id="b" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="270" width="270"><feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity=".225" width="200%" height="200%"/></filter></defs><path style="fill:#e64c3c" d="M4.645 45.577a25.986 25.986 0 0 1-.029-1.154c0-13.997 11.387-25.385 25.385-25.385s25.385 11.387 25.385 25.385c0 .387-.012.771-.029 1.154h4.616c.012-.384.027-.767.027-1.154 0-16.569-13.431-30-30-30s-30 13.431-30 30c0 .387.015.77.029 1.154h4.616z"/><path style="fill:#f0c419" d="M9.289 45.577c-.021-.384-.058-.764-.058-1.154 0-11.452 9.317-20.769 20.769-20.769s20.769 9.318 20.769 20.769c0 .389-.037.77-.058 1.154h4.645c.017-.383.029-.767.029-1.154 0-13.997-11.387-25.385-25.385-25.385S4.615 30.426 4.615 44.423c0 .387.012.771.029 1.154h4.645z"/><path style="fill:#71c285" d="M13.905 45.577c-.027-.383-.058-.764-.058-1.154 0-8.907 7.246-16.154 16.154-16.154s16.154 7.246 16.154 16.154c0 .389-.031.771-.058 1.154h4.615c.021-.384.058-.764.058-1.154 0-11.452-9.317-20.769-20.769-20.769s-20.77 9.317-20.77 20.769c0 .389.037.77.058 1.154h4.616z"/><path style="fill:#0096e6" d="M18.52 45.577a11.58 11.58 0 0 1-.058-1.154c0-6.362 5.176-11.538 11.538-11.538s11.538 5.177 11.538 11.538c0 .389-.021.774-.058 1.154h4.615c.027-.383.058-.764.058-1.154 0-8.907-7.246-16.154-16.154-16.154s-16.154 7.246-16.154 16.154c0 .389.031.771.058 1.154h4.617z"/><path style="fill:#546a79" d="M23.181 45.577a6.859 6.859 0 0 1-.104-1.154c0-3.818 3.105-6.923 6.923-6.923s6.923 3.105 6.923 6.923c0 .394-.041.778-.104 1.154h4.661c.038-.38.058-.764.058-1.154 0-6.362-5.176-11.538-11.538-11.538s-11.538 5.177-11.538 11.538c0 .389.021.774.058 1.154h4.661z"/><defs><linearGradient id="a" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#cb5eee"/><stop offset="1" stop-color="#0cd7e4" stop-opacity=".99"/></linearGradient></defs><text x="32.5" y="231" font-size="27" fill="#fff" filter="url(#b)" font-family="Plus Jakarta Sans,DejaVu Sans,Noto Color Emoji,Apple Color Emoji,sans-serif" font-weight="bold">';
  string svgPartTwo = '</text></svg>';
  mapping(string => address) public domains;
  mapping(string => string) public records;
  mapping (uint => string) public names;

  constructor(string memory _tld) payable ERC721("Damn Name Service", "DNS") {
  owner = payable(msg.sender);
  tld = _tld;
  //console.log("%s name service deployed", _tld);
  }

  modifier onlyOwner() {
    require(isOwner());
    _;
  }

  function register(string calldata name) public payable {
    if (domains[name] != address(0)) revert AlreadyRegistered();
    if (!valid(name)) revert InvalidName(name);

    uint256 _price = price(name);
    require(msg.value >= _price, "Not enough Matic paid");
		
		// Combine the name passed into the function  with the TLD
    string memory _name = string(abi.encodePacked(name, ".", tld));
		// Create the SVG (image) for the NFT with the name
    string memory finalSvg = string(abi.encodePacked(svgPartOne, _name, svgPartTwo));
    uint256 newRecordId = _tokenIds.current();
  	uint256 length = StringUtils.strlen(name);
	  string memory strLen = Strings.toString(length);

    //console.log("Registering %s.%s on the contract with tokenID %d", name, tld, newRecordId);

		// Create the JSON metadata of our NFT. We do this by combining strings and encoding as base64
    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "',
            _name,
            '", "description": "A domain on the Damn Name Service", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(finalSvg)),
            '","length":"',
            strLen,
            '"}'
          )
        )
      )
    );

    string memory finalTokenUri = string( abi.encodePacked("data:application/json;base64,", json));

    _safeMint(msg.sender, newRecordId);
    _setTokenURI(newRecordId, finalTokenUri);
    domains[name] = msg.sender;
    names[newRecordId] = name;

    _tokenIds.increment();
  }

  function price(string calldata name) public pure returns(uint) {
    uint len = StringUtils.strlen(name);
    require(len > 0);
    if (len == 3) {
      return 5 * 10**16; // 5 MATIC = 5 000 000 000 000 000 000 (18 decimals). We're going with 0.5 Matic cause the faucets don't give a lot
    } else if (len == 4) {
      return 3 * 10**16; // To charge smaller amounts, reduce the decimals. This is 0.3
    } else {
      return 1 * 10**16;
    }
  }

  function getAddress(string calldata name) public view returns (address) {
      // Check that the owner is the transaction sender
      return domains[name];
  }

  function setRecord(string calldata name, string calldata record) public {
      // Check that the owner is the transaction sender
      if (msg.sender != domains[name]) revert Unauthorized();
      records[name] = record;
  }

  function getRecord(string calldata name) public view returns(string memory) {
      return records[name];
  }

  function getCounter() public view returns(uint256) {
    return _tokenIds.current();
  }

  function isOwner() public view returns (bool) {
    return msg.sender == owner;
  }

  function withdraw() public onlyOwner {
    uint amount = address(this).balance;
    
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Failed to withdraw Matic");
  }

  function getAllNames() public view returns (string[] memory) {
    string[] memory allNames = new string[](_tokenIds.current());
    for (uint i = 0; i < _tokenIds.current(); i++) {
      allNames[i] = names[i];
    }

    return allNames;
  }

  function valid(string calldata name) public pure returns(bool) {
    return StringUtils.strlen(name) >= 3 && StringUtils.strlen(name) <= 10;
  } 
}