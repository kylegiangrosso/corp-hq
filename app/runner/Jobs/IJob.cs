// Copyright (c) MadDonkeySoftware

namespace Runner.Jobs
{
    /// <summary>
    /// Contract for a job in this system.
    /// </summary>
    public interface IJob
    {
        /// <summary>
        /// Starts the job processing code.
        /// </summary>
        void Start();
    }

    /// <summary>
    /// Contract for a job in this system.
    /// </summary>
    /// <typeparam name="T">The type of data used by this job.</typeparam>
    public interface IJob<T> : IJob
        where T : class
    {
        /// <summary>
        /// Gets or sets the data that is associated with this job.
        /// </summary>
        T Data { get; set; }
    }
}