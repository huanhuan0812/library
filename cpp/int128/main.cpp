#include "int128.h"
#include <iostream>

int main() {
    int128_t a = "123456789012345678901234567890";
    int128_t b = 100;
    
    std::cout << "a = " << a << std::endl;
    std::cout << "a + b = " << a + b << std::endl;
    std::cout << "a * b = " << a * b << std::endl;
    
    return 0;
}