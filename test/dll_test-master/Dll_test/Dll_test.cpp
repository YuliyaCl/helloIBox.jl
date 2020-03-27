// Dll_test.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "DLL_test.h"

int sum_int(int a, int b)
{
	int c;
	c = a + b;
	return c;
}

float sum_float(float e, float f)
{
	float d;
	d = e + f;
	return d;
}

double sum_double(double a, double b)
{
	double c;
	c = a + b;
	return c;
}

void print_array(double* array, int N)
{
	for (int i = 0; i < N; i++)
		std::cout << i << " " << array[i] << std::endl;
}

float add_one(float i)
{
	return i + 1;
}