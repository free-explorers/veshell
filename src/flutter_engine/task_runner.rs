use std::cmp::Ordering;
use std::collections::BinaryHeap;
use std::sync::Mutex;
use std::time::Duration;

use smithay::reexports::calloop::channel;

use crate::flutter_engine::embedder::{FlutterEngineGetCurrentTime, FlutterTask};

type TargetTime = u64;

#[derive(Copy, Clone, Eq, PartialEq)]
struct Task(FlutterTask, TargetTime);

impl PartialEq<Self> for FlutterTask {
    fn eq(&self, other: &Self) -> bool {
        self.task == other.task
    }
}

impl Eq for FlutterTask {}

impl Ord for Task {
    fn cmp(&self, other: &Self) -> Ordering {
        // Flip the ordering so that the BinaryHeap becomes a min-heap.
        // Smaller target times have higher priority.
        // In case of a tie we compare the task ID.
        // This step is necessary to make implementations of `PartialEq` and `Ord` consistent.
        other.1.cmp(&self.1).then_with(|| self.0.task.cmp(&other.0.task))
    }
}

impl PartialOrd<Self> for Task {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

pub struct TaskRunner {
    tasks: Mutex<BinaryHeap<Task>>,
    expired_tasks: Vec<Task>,
    pub reschedule_timer: channel::Sender<Duration>,
}

impl TaskRunner {
    pub fn new(reschedule_timer: channel::Sender<Duration>) -> Self {
        Self {
            tasks: Mutex::new(BinaryHeap::new()),
            expired_tasks: Vec::new(),
            reschedule_timer,
        }
    }

    pub fn enqueue_task(&mut self, task: FlutterTask, target_time: TargetTime) -> Duration {
        {
            let mut tasks = self.tasks.lock().unwrap();
            tasks.push(Task(task, target_time));
        }
        self.reschedule_timer()
    }

    pub fn execute_expired_tasks(&mut self, execute_task: impl Fn(&FlutterTask)) -> Duration {
        assert!(self.expired_tasks.is_empty());

        {
            let mut tasks = self.tasks.lock().unwrap();
            while let Some(task) = tasks.peek() {
                let Task(_, target_time) = *task;
                if target_time > unsafe { FlutterEngineGetCurrentTime() } {
                    // Target time is in the future.
                    break;
                }
                self.expired_tasks.push(tasks.pop().unwrap());
            }
        }

        for Task(task, _) in self.expired_tasks.drain(..) {
            execute_task(&task);
        }

        self.reschedule_timer()
    }

    fn reschedule_timer(&self) -> Duration {
        let tasks = self.tasks.lock().unwrap();

        match tasks.peek() {
            None => {
                // Just set the timer to an arbitrary long duration.
                // We don't want to drop the timer because it will rescheduled when new tasks arrive.
                // For some reason Duration::MAX doesn't work so I've randomly chosen 1 minute.
                Duration::from_secs(60)
            }
            Some(Task(_, target_time)) => {
                let now = unsafe { FlutterEngineGetCurrentTime() };
                let duration_ns = target_time.checked_sub(now).unwrap_or(0);
                Duration::from_nanos(duration_ns)
            }
        }
    }
}
