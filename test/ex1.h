#ifndef ARRAYMAKER_H2
#define ARRAYMAKER_H2

class IBoxInterface
{
    public:
        virtual void getData(char * _name, char * _dest, int _index, int _start, int _count) = NULL;
};

#endif
