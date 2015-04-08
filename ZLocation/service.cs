using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.ServiceModel;

namespace ZLocation
{
    [ServiceContract()]
    public interface IService
    {
        [OperationContract()]
        void Add(string path, double weight);

        [OperationContract()]
        void Remove(string path);

        [OperationContract()]
        IEnumerable<KeyValuePair<string, double>> Get();

        [OperationContract()]
        void Noop();
    }

    [ServiceBehavior(InstanceContextMode = InstanceContextMode.Single)]
    public class Service : IService
    {
        private ConcurrentDictionary<string, double> _data;
        private string _backupFileFullPath;
        private readonly TimeSpan _backupThreshold;
        private DateTime _lastBackupTime;


        /// <summary>
        /// Create the Service with backup threshold time 1 sec.
        /// </summary>
        /// <param name="backupFileFullPath"></param>
        public Service(string backupFileFullPath)
            : this(backupFileFullPath, TimeSpan.FromSeconds(1))
        {
        }

        public Service(string backupFileFullPath, TimeSpan backupThreshold)
        {
            this._backupFileFullPath = backupFileFullPath;
            this._backupThreshold = backupThreshold;
            this._data = new ConcurrentDictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            if (File.Exists(_backupFileFullPath))
            {
                foreach (var line in File.ReadAllLines(_backupFileFullPath))
                {
                    var items = line.Split('\t');
                    double weight;
                    if (items.Length == 2 && Double.TryParse(items[1], out weight))
                    {
                        _data[items[0]] = weight;
                    }
                }
            }
            _lastBackupTime = DateTime.Now;
        }

        public void Add(string path, double weight)
        {
            double oldWeight = 0;
            _data.TryGetValue(path, out oldWeight);
            _data[path] = oldWeight + weight;
            this.Backup();
        }

        public void Remove(string path)
        {
            double oldWeight = 0;
            _data.TryRemove(path, out oldWeight);
            this.Backup();
        }        

        private void Backup()
        {
            if (DateTime.Now.Subtract(_lastBackupTime).CompareTo(_backupThreshold) > 0)
            {
                var lines = _data.Select(pair => pair.Key + "\t" + pair.Value);
                File.WriteAllLines(_backupFileFullPath, lines);
                _lastBackupTime = DateTime.Now;
            }
        }

        public IEnumerable<KeyValuePair<string, double>> Get()
        {
            return _data.ToArray();
        }

        public void Noop()
        {
        }
    }
}
