## Build LuaJIT

### Windows

In Visual Studio Developer Command Prompt:
```shell    
cd <Flexilite_location>
copy .\luajit_msvcbuild.bat .\lib\torch-luajit-rocks\luajit-2.1\src\msvcbuild.bat
cd .\lib\torch-luajit-rocks\luajit-2.1\src
setenv /release /x86
or
setenv /release /x64
msvcbuild static
```

### macOS

``` shell
cd <Flexilite_location>
cd ./lib/torch-luajit-rocks
mkdir ./build
cd ./build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/torch -DWITH_LUAJIT21=ON 
make
```

To install Torch LuaJIT and LuaRocks run this command:
```
sudo make install
sudo /usr/torch/bin/luarocks install penlight
```

Add Torch binaries to PATH :

```shell
sudo nano ~/.profile
```

Append the following line to the end of file:

```shell
export PATH=$PATH:/usr/torch/bin 

```
 

### Linux (Ubuntu, Debian)

``` shell
sudo apt-get install libc6-dbg gdb valgrind
```

``` shell
cd <Flexilite_location>
cd ./lib/torch-luajit-rocks
mkdir ./build
cd ./build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/torch -DWITH_LUAJIT21=ON 
make 
```

### Install dependencies

```shell
cd ./lib/debugger-lua && luajit embed/debugger.c.lua
```

## Test

[busted](https://github.com/Olivine-Labs/busted) is used to run Flexilite tests

Since by default **busted** expects Lua 5.3, and Flexilite is based on LuaJIT 2.1,
it needs to run with the following setting:

```shell
busted --lua=<PATH_TO_LUAJIT> test.lua
```
