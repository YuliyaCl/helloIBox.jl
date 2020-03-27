#pragma once
#include <iostream>

#ifdef DLL_TEST_EXPORTS
#define DLL_TEST_API __declspec(dllexport)
#else
#define DLL_TEST_API __declspec(dllimport)
#endif

extern "C" DLL_TEST_API int sum_int(int a, int b);

extern "C" DLL_TEST_API float sum_float(float e, float f);

extern "C" DLL_TEST_API double sum_double(double a, double b);

extern "C" DLL_TEST_API void print_array(double* array, int N);

extern "C"  DLL_TEST_API float add_one(float i);
