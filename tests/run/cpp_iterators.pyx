# mode: run
# tag: cpp, werror, no-cpp-locals

from libcpp.deque cimport deque
from libcpp.vector cimport vector
from cython.operator cimport dereference as deref

cdef extern from "cpp_iterators_simple.h":
    cdef cppclass DoublePointerIter:
        DoublePointerIter(double* start, int len)
        double* begin()
        double* end()
    cdef cppclass DoublePointerIterDefaultConstructible:
        DoublePointerIterDefaultConstructible()
        DoublePointerIterDefaultConstructible(double* start, int len)
        double* begin()
        double* end()

def test_vector(py_v):
    """
    >>> test_vector([1, 2, 3])
    [1, 2, 3]
    """
    cdef vector[int] vint = py_v
    cdef vector[int] result
    with nogil:
        for item in vint:
            result.push_back(item)
    return result

def test_deque_iterator_subtraction(py_v):
    """
    >>> print(test_deque_iterator_subtraction([1, 2, 3]))
    3
    """
    cdef deque[int] dint
    for i in py_v:
        dint.push_back(i)
    cdef deque[int].iterator first = dint.begin()
    cdef deque[int].iterator last = dint.end()

    return last - first

def test_vector_iterator_subtraction(py_v):
    """
    >>> print(test_vector_iterator_subtraction([1, 2, 3]))
    3
    """
    cdef vector[int] vint = py_v
    cdef vector[int].iterator first = vint.begin()
    cdef vector[int].iterator last = vint.end()

    return last - first

def test_deque_iterator_addition(py_v):
    """
    >>> test_deque_iterator_addition([2, 4, 6])
    6
    """
    cdef deque[int] dint
    for i in py_v:
        dint.push_back(i)
    cdef deque[int].iterator first = dint.begin()

    return deref(first+2)

def test_vector_iterator_addition(py_v):
    """
    >>> test_vector_iterator_addition([2, 4, 6])
    6
    """
    cdef vector[int] vint = py_v
    cdef vector[int].iterator first = vint.begin()

    return deref(first+2)

def test_ptrs():
    """
    >>> test_ptrs()
    [1.0, 2.0, 3.0]
    """
    cdef double a = 1
    cdef double b = 2
    cdef double c = 3
    cdef vector[double*] v
    v.push_back(&a)
    v.push_back(&b)
    v.push_back(&c)
    return [item[0] for item in v]

def test_custom():
    """
    >>> test_custom()
    [1.0, 2.0, 3.0]
    """
    cdef double* values = [1, 2, 3]
    cdef DoublePointerIter* iter
    try:
        iter = new DoublePointerIter(values, 3)
        # TODO: It'd be nice to automatically dereference this in a way that
        # would not conflict with the pointer slicing iteration.
        return [x for x in iter[0]]
    finally:
        del iter

def test_custom_deref():
    """
    >>> test_custom_deref()
    [1.0, 2.0, 3.0]
    """
    cdef double* values = [1, 2, 3]
    cdef DoublePointerIter* iter
    try:
        iter = new DoublePointerIter(values, 3)
        return [x for x in deref(iter)]
    finally:
        del iter

def test_custom_genexp():
    """
    >>> test_custom_genexp()
    [1.0, 2.0, 3.0]
    """
    def to_list(g):  # function to hide the intent to avoid inlined-generator expression optimization
        return list(g)
    cdef double* values = [1, 2, 3]
    cdef DoublePointerIterDefaultConstructible* iter
    try:
        iter = new DoublePointerIterDefaultConstructible(values, 3)
        # TODO: Only needs to copy once - currently copies twice
        return to_list(x for x in iter[0])
    finally:
        del iter

def test_iteration_over_heap_vector(L):
    """
    >>> test_iteration_over_heap_vector([1,2])
    [1, 2]
    """
    cdef int i
    cdef vector[int] *vint = new vector[int]()
    try:
        for i in L:
            vint.push_back(i)
        return [ i for i in deref(vint) ]
    finally:
        del vint

def test_iteration_in_generator(vector[int] vint):
    """
    >>> list( test_iteration_in_generator([1,2]) )
    [1, 2]
    """
    for i in vint:
        yield i

def test_iteration_in_generator_reassigned():
    """
    >>> list( test_iteration_in_generator_reassigned() )
    [1]
    """
    cdef vector[int] *vint = new vector[int]()
    cdef vector[int] *orig_vint = vint
    vint.push_back(1)
    reassign = True
    try:
        for i in deref(vint):
            yield i
            if reassign:
                reassign = False
                vint = new vector[int]()
                vint.push_back(2)
    finally:
        if vint is not orig_vint:
            del vint
        del orig_vint

cdef extern from *:
    """
    std::vector<int> make_vec1() {
        std::vector<int> vint;
        vint.push_back(1);
        vint.push_back(2);
        return vint;
    }
    """
    cdef vector[int] make_vec1() except +

cdef vector[int] make_vec2() except *:
    return make_vec1()

cdef vector[int] make_vec3():
    try:
        return make_vec1()
    except:
        pass

def test_iteration_from_function_call():
    """
    >>> test_iteration_from_function_call()
    1
    2
    1
    2
    1
    2
    """
    for i in make_vec1():
        print(i)
    for i in make_vec2():
        print(i)
    for i in make_vec3():
        print(i)

def test_const_iterator_calculations(py_v):
    """
    >>> print(test_const_iterator_calculations([1, 2, 3]))
    [3, 3, 3, 3, True, True, False, False]
    """
    cdef deque[int] dint
    for i in py_v:
        dint.push_back(i)
    cdef deque[int].iterator first = dint.begin()
    cdef deque[int].iterator last = dint.end()
    cdef deque[int].const_iterator cfirst = first
    cdef deque[int].const_iterator clast = last

    return [
        last - first,
        last - cfirst,
        clast - first,
        clast - cfirst,
        first == cfirst,
        last == clast,
        first == clast,
        last == cfirst
    ]

cdef extern from "cpp_iterators_over_attribute_of_rvalue_support.h":
    cdef cppclass HasIterableAttribute:
        vector[int] vec
        HasIterableAttribute()
        HasIterableAttribute(vector[int])

cdef HasIterableAttribute get_object_with_iterable_attribute():
    return HasIterableAttribute()

def test_iteration_over_attribute_of_call():
    """
    >>> test_iteration_over_attribute_of_call()
    1
    2
    3
    42
    43
    44
    1
    2
    3
    """
    for i in HasIterableAttribute().vec:
        print(i)
    cdef vector[int] vec
    for i in range(42, 45):
        vec.push_back(i)
    for i in HasIterableAttribute(vec).vec:
        print(i)
    for i in get_object_with_iterable_attribute().vec:
        print(i)

