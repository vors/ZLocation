using System;
using System.Collections.Concurrent;
using System.Collections.Generic;

namespace ZLocation
{
    public class MockServiceProxy
    {
        public void Add(string path, double weight) { throw new NotImplementedException(); }

        public void Remove(string path){ throw new NotImplementedException(); }

        public IEnumerable<KeyValuePair<string, double>> Get(){ throw new NotImplementedException(); }

        public void Noop(){ throw new NotImplementedException(); }
    }
}
