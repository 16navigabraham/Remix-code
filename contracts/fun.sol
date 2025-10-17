// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FunMe{
    struct user{
    string username;
    string bio;
    bytes32 pfp;
    }
    mapping (string=> user) users;

    function Adduser(string memory  _username,string memory  _bio, bytes32 _pfp)
    public{
        users [_username]= user(_username,_bio,_pfp);
    }

    function Getuser(string memory  _username)public view returns(user memory)  {
       return users[_username] ;
    }
}